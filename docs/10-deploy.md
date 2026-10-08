---
title: 10. Deploy through Fabric CI/CD
nav_order: 11
---

# Step 10 — Deploy through Fabric CI/CD

**Goal:** release the solution you already built into **Contoso Sales Test**, a separate workspace,
using reviewed source and a secretless deployment identity. Do not rebuild the notebook, model,
or report from Steps 6–8, and do not deploy back into Git-connected Dev.

**What Copilot uses:** **Agent mode in VS Code**, the existing Fabric MCP and Fabric extension,
**Power BI Modeling MCP**, **MSSQL**, and the **GitHub Pull Requests** and **GitHub Actions**
extensions. Copilot generates the `fabric-cicd` publisher and workflow; Actions executes the
deployment. For workspace/capacity and identity setup, Copilot runs `fab`, `az`, and `gh`.
The command references below show what it runs, not a different, CLI-first tutorial.

## Where you are

Continue in the **solution repo**, after the [Step 9 PR](09-review-in-github.md#4-review-the-checks-then-merge)
has been reviewed and merged into `main`. Your existing Dev work remains the foundation:

| | Development | Release validation |
| --- | --- | --- |
| Workspace | `Contoso Sales Dev` | `Contoso Sales Test`, created here |
| Definition updates | Explicit Git commit/update with `build/contoso-sales` | `fabric-cicd` from reviewed `main` |
| Git connection | `src/fabric` on the development branch | **None** |
| Source fixture | Existing `data/raw/sales.csv` | New `data/raw/sales-test.csv` |
| Expected Revenue | 11,100 | 22,200 |

**Git sync is not deployment automation.** A push does not automatically update Dev; see
[Step 3](03-connect-github.md). This chapter adds an actual push-to-`main` deployment trigger,
targeting Test only.

**Definitions are not data.** Publishing a Lakehouse does not copy Dev's CSV or Delta rows. The
two fixtures stand in for separate source-system inputs. Both land at
`Files/contoso/raw/sales.csv`, but in **different Lakehouses**, so the same notebook works in both.
In a real solution, ingestion would maintain each environment's landing data using its own
source connection. Here, one explicit file-staging step simulates that ingestion.

## 1. Ask Copilot to inspect release readiness

```
Continue from the reviewed Contoso sales solution on main. Do not rebuild any
Dev artifacts. Inspect the local branch/worktree, the Fabric item definitions,
and the Dev workspace. Record the Dev workspace, lakehouse, and semantic-model
IDs needed to remap the existing definitions; do not commit those IDs in scripts.

Check readiness for deployment to a separate "Contoso Sales Test" workspace:
the existing capacity, az/fab/gh authentication and tenant, Entra app-registration
rights, Fabric workspace permissions, and GitHub repository administration.
Confirm the relevant Fabric, Modeling, MSSQL, GitHub PR, and Actions tools are
enabled in VS Code. Identify administrator handoffs. This is read-only.
```

Copilot reports prerequisites before proposing writes. The permissions belong to different systems:

| Action | Who needs permission |
| --- | --- |
| Create Test and assign the existing capacity | The signed-in learner/workspace operator |
| Register or manage the Entra application and federated credential | An authorized Entra user/app owner; ask an administrator if app creation is restricted |
| Allow service-principal API access for the relevant security group | A **Fabric tenant administrator** |
| Grant the deployment identity Test access | A Test workspace Member or Admin |
| Configure repository variables and review/branch controls | An authorized GitHub repository administrator |

The deployment principal needs **Contributor on Test** for item REST publishing, not Azure
subscription Contributor and not access to Dev. Microsoft documents that role and service-principal
support for [semantic-model creation](https://learn.microsoft.com/rest/api/fabric/semanticmodel/items/create-semantic-model).
Model authoring/verification through XMLA still uses the learner's authorized Modeling MCP session
and the capacity configuration from Step 7.

> **Two identities, not one shared login.** Your interactive sessions perform setup and the first
> data load. GitHub Actions later authenticates as a dedicated service principal. OIDC establishes
> that identity; Fabric's tenant policy and workspace role authorize it. Successful Azure login
> alone does not prove Fabric access. Source-system credentials, if you later replace the CSV
> simulation, are a separate runtime concern.

## 2. Prepare the Test fixture and publisher through a PR

Use the review process you already learned; do not replace Step 9's CI or Dev checks:

```
From a clean, up-to-date main, create a setup/test-release branch. Show changes
before writing them:

1. Keep data/raw/sales.csv unchanged. Create data/raw/sales-test.csv with the
   same seven records, schema, dates, keys, prices, and costs, but double every
   Quantity. Do not change the transformation, measures, or report design.
2. Extend scripts/validate_demo_data.py with --environment dev|test; no argument
   must still run the existing Dev checks. Test reads sales-test.csv and checks
   7 rows, unique OrderId, valid keys/numeric values, and exact totals:
   Revenue 22,200; Cost 15,600; Margin 6,600. Use decimal arithmetic. Check that
   both fixtures have the same non-Quantity fields and Test quantities are
   exactly twice Dev's. Fail clearly on invalid data, do not silently repair it.
3. Extend validate.yml to run the existing checks plus the Test invocation.
   Keep the package pins and existing secret/definition checks.
4. Generate scripts/deploy_workspace.py and src/fabric/parameter.yml following
   the publisher and binding contract below. Include an explicit --data-only
   bootstrap mode; the default publishes the full solution. Add offline tests
   for wrong-target/missing-variable guards and parameter mappings.
5. Append a short deployment section to this solution repo's Copilot instructions:
   author in Dev, publish reviewed main to Test, never deploy to Dev or copy
   its populated data. Preserve all the existing instructions.

Do not create or enable deploy.yml yet. Run the local checks, inspect the diff,
then open a PR into main. Stop for review; merge only after approval and passing
checks. Pull the reviewed main before the bootstrap.
```

The new fixture is exactly:

```csv
OrderId,OrderDate,CustomerId,CustomerName,ProductId,ProductName,Category,RegionId,RegionName,Quantity,UnitPrice,UnitCost
SO1001,2024-01-15,C001,Alpine Ski House,P100,Pro Laptop,Devices,R01,East,4,1200.00,900.00
SO1002,2024-02-20,C002,Blue Yonder Airlines,P200,Wide Monitor,Accessories,R01,East,6,300.00,200.00
SO1003,2024-03-10,C003,Contoso Retail,P300,Standing Desk,Furniture,R02,West,2,800.00,500.00
SO2001,2025-01-15,C001,Alpine Ski House,P100,Pro Laptop,Devices,R01,East,6,1200.00,900.00
SO2002,2025-02-20,C002,Blue Yonder Airlines,P200,Wide Monitor,Accessories,R01,East,8,300.00,200.00
SO2003,2025-03-10,C003,Contoso Retail,P300,Standing Desk,Furniture,R02,West,4,800.00,500.00
SO2004,2025-03-12,C004,Delta Traders,P200,Wide Monitor,Accessories,R02,West,4,300.00,200.00
```

In **GitHub Pull Requests**, verify the original CSV, notebook, measures, and report layout are
unchanged. Both fixture checks must pass:

```powershell
python .\scripts\validate_demo_data.py
python .\scripts\validate_demo_data.py --environment test
```

See the [separate Test expectations](reference.md#test-fixture-step-10-onward). Counts and percentage
measures stay the same; monetary values double. A Test report showing Revenue **11,100** is wrong,
even if deployment is green.

## Parameterize environment-specific IDs

The source definitions legitimately carry Dev binding GUIDs, as explained in Step 9. Keep those
definitions as the baseline; use `fabric-cicd` parameterization when publishing. Its
[`parameter.yml` belongs at the root of `repository_directory`](https://microsoft.github.io/fabric-cicd/1.3.0/how_to/parameterization/):
here, **`src/fabric/parameter.yml`**, not beside the Python script. Pass `environment="test"`.

This starting configuration uses the library's environment-variable replacement flag for source
lookup IDs and its dynamic item references for destination IDs. No Test GUID is committed:

```yaml
find_replace:
  - find_value: "$ENV:FABRIC_DEV_WORKSPACE_ID"
    replace_value:
      test: "$workspace.$id"
    ignore_case: "true"
  - find_value: "$ENV:FABRIC_DEV_LAKEHOUSE_ID"
    replace_value:
      test: "$items.Lakehouse.ContosoSalesLH.$id"
    ignore_case: "true"
  - find_value: "$ENV:FABRIC_DEV_MODEL_ID"
    replace_value:
      test: "$items.SemanticModel.Contoso Sales.$id"
    ignore_case: "true"
    file_path: "/Contoso Sales.Report/definition.pbir"
  - find_value: "Contoso Sales Dev"
    replace_value:
      test: "Contoso Sales Test"
    file_path: "/Contoso Sales.Report/definition.pbir"
  - find_value: "Contoso%20Sales%20Dev"
    replace_value:
      test: "Contoso%20Sales%20Test"
    file_path: "/Contoso Sales.Report/definition.pbir"
```

Have Copilot inspect the **actual** bindings before accepting this file:

- The notebook's default and any attached Lakehouse references must resolve to Test.
- The Direct Lake expression must reference Test's OneLake workspace/Lakehouse, not Dev.
- The locally authored report uses **`byConnection`**. Remap its model ID and any XMLA workspace
  address, including a URL-encoded name. Do not assume the library's automatic **`byPath`**
  report rebinding covers this representation.
- If the model uses an explicit Fabric data connection, provision/authorize the appropriate
  Test connection and configure the library's `semantic_model_binding` parameter. A changed
  OneLake URL does not supply credentials or connection permissions.
- In Step 11, inspect the pipeline's notebook/model/workspace IDs and connections too. Extend
  scoped mappings for any object-ID references not handled by logical-ID rebinding.

The mappings are applied to deployment payloads, not by rewriting source definitions with ad hoc
string replacements. The library discovers destination items as it publishes dependencies.
Source lookup IDs come from the reviewed definitions and must be updated if Dev items are recreated;
the Actions principal does not need permission to look up Dev at runtime.

### Publisher example Copilot generates

Use **Python 3.13** and the existing `fabric-cicd==1.3.0` pin. This publisher explicitly uses
[`AzureCliCredential`](https://microsoft.github.io/fabric-cicd/1.3.0/example/authentication/):
your `az login` locally, and the OIDC login in Actions. The preflight is read-only and fails before
publishing if the target is wrong, unassigned, or Git-connected.

```python
import argparse
import json
import os
from pathlib import Path
from urllib.request import Request, urlopen
from uuid import UUID

from azure.identity import AzureCliCredential
from fabric_cicd import FabricWorkspace, append_feature_flag, publish_all_items


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--data-only", action="store_true")
    args = parser.parse_args()

    source_variables = (
        "FABRIC_DEV_WORKSPACE_ID",
        "FABRIC_DEV_LAKEHOUSE_ID",
        "FABRIC_DEV_MODEL_ID",
    )
    for name in ("AZURE_TENANT_ID", "FABRIC_TEST_WORKSPACE_ID", *source_variables):
        value = os.environ.get(name, "").strip()
        if not value:
            raise ValueError(f"Required configuration is missing: {name}")
        UUID(value)
        os.environ[name] = value

    target_id = os.environ["FABRIC_TEST_WORKSPACE_ID"]
    if UUID(target_id) == UUID(os.environ["FABRIC_DEV_WORKSPACE_ID"]):
        raise ValueError("Refusing to deploy into Dev.")
    if os.environ.get("GITHUB_ACTIONS") == "true":
        if os.environ.get("GITHUB_REF") != "refs/heads/main" or args.data_only:
            raise ValueError("Actions may only run a full deployment from main.")

    repository_directory = Path(__file__).resolve().parents[1] / "src" / "fabric"
    if not (repository_directory / "parameter.yml").is_file():
        raise FileNotFoundError("src/fabric/parameter.yml is required.")

    credential = AzureCliCredential(tenant_id=os.environ["AZURE_TENANT_ID"])

    def read_fabric(path):
        token = credential.get_token("https://api.fabric.microsoft.com/.default").token
        request = Request(
            f"https://api.fabric.microsoft.com/v1/{path}",
            headers={
                "Authorization": f"Bearer {token}",
                "x-ms-fabric-skill": "git-integration-operations-cli",
            },
        )
        with urlopen(request, timeout=30) as response:
            return json.load(response)

    workspace = read_fabric(f"workspaces/{target_id}")
    if workspace["displayName"] != "Contoso Sales Test" or not workspace.get("capacityId"):
        raise ValueError("Target must be the capacity-assigned Contoso Sales Test workspace.")
    connection = read_fabric(f"workspaces/{target_id}/git/connection")
    if connection["gitConnectionState"] != "NotConnected":
        raise ValueError("Test must not be Git-connected. Do not disconnect it automatically.")

    append_feature_flag("enable_environment_variable_replacement")
    for name in source_variables:
        os.environ[f"$ENV:{name}"] = os.environ[name]

    item_types = ["Lakehouse", "Notebook"]
    if not args.data_only:
        item_types += ["SemanticModel", "Report", "DataPipeline"]

    target = FabricWorkspace(
        workspace_id=target_id,
        repository_directory=str(repository_directory),
        environment="test",
        item_type_in_scope=item_types,
        token_credential=credential,
    )
    publish_all_items(target)


if __name__ == "__main__":
    main()
```

The explicit `$ENV:` entries are how this pinned library receives parameter-file variables; ordinary
environment variables alone do not enable their substitution. **Do not add orphan deletion**:
this tutorial creates/updates the reviewed items and reports unexpected extras rather than deleting
them. `--data-only` is a one-time preparation mode, not the normal release.

## 3. Ask Copilot to create the separate Test workspace

```
Using fab, inspect "Contoso Sales Test" and the existing centralfabriccapacity.
If Test does not exist, propose creating it on that capacity. If it exists,
inspect its items and Git connection first; stop on an unexpected populated or
Git-connected workspace rather than overwriting or disconnecting it.

After approval, create/assign as needed. Verify capacityAssignmentProgress is
Completed, compare workspace capacityId with capacity fabricId, and report the
Test workspace ID. Confirm it differs from Dev and is not Git-connected.
Do not create items or another capacity yet.
```

Copilot follows the same capacity verification you used in Step 2:

```powershell
fab auth status
fab exists "Contoso Sales Test.Workspace"
fab ls .capacities
```

Only after confirming the capacity exists, and **only if `exists` returned False**:

```powershell
fab mkdir "Contoso Sales Test.Workspace" -P capacityName=centralfabriccapacity
```

For an **existing, approved target** that needs assignment, use this instead of `mkdir`:

```powershell
fab assign ".capacities/centralfabriccapacity.Capacity" -W "Contoso Sales Test.Workspace"
```

Then verify:

```powershell
fab exists "Contoso Sales Test.Workspace"
fab get "Contoso Sales Test.Workspace" -q .
fab get ".capacities/centralfabriccapacity.Capacity" -q .
fab ls "Contoso Sales Test.Workspace"
```

The first-time listing must be empty. Refresh **Fabric explorer** in VS Code and identify Dev and
Test separately. If resuming a partially completed release, inspect its existing items and obtain
approval to reuse them; do not blindly recreate them.

## 4. Ask Copilot to configure the deployment identity

```
Set up secretless GitHub Actions deployment from this repository's main branch
to "Contoso Sales Test". Use az for a dedicated single-tenant Entra application,
its service principal, and the GitHub OIDC federated credential; fab api for
Test workspace access; and gh for OIDC settings discovery/repository variables.

Inspect before creating, reuse exact compatible matches, and stop on ambiguous
names, conflicting trusts, or unexpected existing access. Show each proposed
change before applying it. Never create a client secret, grant Dev access,
assign an Azure subscription role, or change tenant-wide policy.

Give me the precise Fabric administrator handoff if the principal is not allowed
by tenant policy. Pause for interactive sign-in or missing authorization.
Verify the resulting configuration without printing tokens or other secrets.
```

Copilot can automate the permitted steps. It cannot grant itself Entra/Fabric administration.
Run interactive login in a real terminal when requested, including `fab auth login` from Step 1.
The following reference is also usable by an authorized administrator.

<details markdown="1">
<summary>What Copilot runs: application and main-bound OIDC trust (PowerShell)</summary>

Use the same terminal for these blocks. Fill in the **non-secret** tenant/repository values.
The helper stops on native-command errors; it does not hide an authorization failure.

```powershell
$ErrorActionPreference = 'Stop'
function Invoke-Checked {
    param([string]$Tool, [string[]]$Arguments)
    $output = & $Tool @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Tool failed with exit code $LASTEXITCODE." }
    $output
}

$repo = '<owner>/contoso-sales-fabric'
$tenantId = '<Fabric-tenant-id>'
$appName = 'contoso-sales-fabric-test-deployer'
Invoke-Checked az @('login', '--tenant', $tenantId, '--allow-no-subscriptions')
Invoke-Checked gh @('auth', 'status')
Invoke-Checked fab @('auth', 'status')

$apps = @(Invoke-Checked az @('ad', 'app', 'list', '--display-name', $appName, '-o', 'json') |
    ConvertFrom-Json | Where-Object displayName -EQ $appName)
if ($apps.Count -gt 1) { throw 'Ambiguous application name; select the intended app explicitly.' }
if ($apps.Count -eq 0) {
    $app = Invoke-Checked az @('ad', 'app', 'create', '--display-name', $appName,
        '--sign-in-audience', 'AzureADMyOrg', '-o', 'json') | ConvertFrom-Json
} else {
    $app = $apps[0]
}
if ($app.signInAudience -ne 'AzureADMyOrg') { throw 'Expected a dedicated single-tenant app.' }
$clientId = $app.appId
$appObjectId = $app.id

$principals = @(Invoke-Checked az @('ad', 'sp', 'list', '--filter',
    "appId eq '$clientId'", '-o', 'json') | ConvertFrom-Json)
if ($principals.Count -gt 1) { throw 'Ambiguous service principal.' }
if ($principals.Count -eq 0) {
    $sp = Invoke-Checked az @('ad', 'sp', 'create', '--id', $clientId, '-o', 'json') |
        ConvertFrom-Json
} else {
    $sp = $principals[0]
}
$spObjectId = $sp.id

$repository = Invoke-Checked gh @('api', "repos/$repo") | ConvertFrom-Json
$oidc = Invoke-Checked gh @('api', "repos/$repo/actions/oidc/customization/sub") |
    ConvertFrom-Json
if ($oidc.use_default -ne $true) {
    throw 'Custom OIDC subject policy: inspect with the repo admin; do not overwrite it.'
}
if ($oidc.sub_claim_prefix) {
    $prefix = $oidc.sub_claim_prefix
} elseif ($oidc.use_immutable_subject -eq $true) {
    $prefix = "repo:$($repository.owner.login)@$($repository.owner.id)/$($repository.name)@$($repository.id)"
} elseif ($oidc.use_immutable_subject -eq $false) {
    $prefix = "repo:$($repository.full_name)"
} else {
    throw 'OIDC subject format is unknown; confirm the effective policy before creating trust.'
}
$subject = "${prefix}:ref:refs/heads/main"
$issuer = 'https://token.actions.githubusercontent.com'
$audience = 'api://AzureADTokenExchange'
$credentialName = 'github-main-test'

$credentials = @(Invoke-Checked az @('ad', 'app', 'federated-credential', 'list',
    '--id', $appObjectId, '-o', 'json') | ConvertFrom-Json)
$existing = @($credentials | Where-Object name -EQ $credentialName)
if ($existing.Count -gt 1) { throw 'Ambiguous federated credential.' }
if ($existing.Count -eq 1) {
    if ($existing[0].issuer -cne $issuer -or $existing[0].subject -cne $subject -or
        @($existing[0].audiences).Count -ne 1 -or $existing[0].audiences[0] -cne $audience) {
        throw 'Existing federated trust differs; review instead of replacing it.'
    }
} else {
    $body = @{
        name = $credentialName
        issuer = $issuer
        subject = $subject
        audiences = @($audience)
    } | ConvertTo-Json
    $file = Join-Path ([IO.Path]::GetTempPath()) ("contoso-oidc-{0}.json" -f [guid]::NewGuid())
    try {
        $body | Set-Content -LiteralPath $file -Encoding utf8
        Invoke-Checked az @('ad', 'app', 'federated-credential', 'create',
            '--id', $appObjectId, '--parameters', $file, '-o', 'json')
    } finally {
        if (Test-Path -LiteralPath $file) { Remove-Item -LiteralPath $file }
    }
}
Invoke-Checked az @('ad', 'app', 'federated-credential', 'list', '--id', $appObjectId, '-o', 'json')
```

The temporary JSON contains **trust metadata, not a secret**, and is removed. Verify the exact
issuer, audience, and main-branch subject. The **client ID** authenticates the app; the
**application object ID** identifies its registration; the **service principal object ID** is
used for group membership and Fabric permissions. They are not interchangeable.

GitHub's [OIDC subject formats](https://docs.github.com/en/actions/reference/security/oidc#example-subject-claims)
include immutable owner/repository IDs for newer repositories. Inspect the
[effective repository settings](https://docs.github.com/en/rest/actions/oidc) rather than blindly
copying a legacy `repo:owner/name:ref:refs/heads/main` string. Also review any other federated
credentials on a reused app; do not assume the named credential is its only trust.

</details>

### Fabric administrator handoff

A Fabric administrator must verify **Service principals can call Fabric public APIs** (also called
**Service principals can use Fabric APIs**) permits this principal, preferably through a dedicated
approved security group. See [developer tenant settings](https://learn.microsoft.com/fabric/admin/service-admin-portal-developer).
Do not enable access tenant-wide just to unblock the tutorial. The separate setting allowing
principals to **create workspaces/connections/deployment pipelines** is not required for this
publisher: the operator creates Test, and Actions publishes items into it.

If an authorized group owner/admin must add the principal to the approved group, Copilot can show
and run these commands. Add only when the membership check reports `false`, then check again:

```powershell
$allowedGroupId = '<approved-security-group-object-id>'
$membership = Invoke-Checked az @('ad', 'group', 'member', 'check',
    '--group', $allowedGroupId, '--member-id', $spObjectId) | ConvertFrom-Json
if ($membership.value -eq $false) {
    Invoke-Checked az @('ad', 'group', 'member', 'add',
        '--group', $allowedGroupId, '--member-id', $spObjectId)
}
$membership = Invoke-Checked az @('ad', 'group', 'member', 'check',
    '--group', $allowedGroupId, '--member-id', $spObjectId) | ConvertFrom-Json
if ($membership.value -ne $true) { throw 'Approved group membership was not verified.' }
```

Group membership alone does not enable a tenant setting or grant workspace access. Wait for the
administrator's confirmation before the first unattended deployment.

<details markdown="1">
<summary>What Copilot runs: Test workspace role and repository variables</summary>

Use the IDs verified by Copilot, not values copied from an unrelated workspace. The Fabric CLI
already has the operator's interactive login; **do not log it in using a fabricated OIDC token**.
This helper checks the API response as well as the command exit code:

```powershell
$devWorkspaceId = '<verified-Dev-workspace-id>'
$devLakehouseId = '<Dev-lakehouse-id-in-reviewed-source>'
$devModelId = '<Dev-model-id-in-reviewed-report>'
$testWorkspaceId = '<verified-Test-workspace-id>'
if ([guid]$testWorkspaceId -eq [guid]$devWorkspaceId) { throw 'Test must differ from Dev.' }

function Invoke-FabricJson {
    param([string[]]$Arguments)
    $reply = Invoke-Checked fab (@('api') + $Arguments +
        @('-H', 'x-ms-fabric-skill=git-integration-operations-cli')) | ConvertFrom-Json
    if ($reply.status_code -notin @(200, 201)) {
        throw "Fabric request did not complete: $($reply | ConvertTo-Json -Depth 10 -Compress)"
    }
    $reply.text
}

$target = Invoke-FabricJson @('-X', 'get', "workspaces/$testWorkspaceId")
if ($target.displayName -ne 'Contoso Sales Test' -or -not $target.capacityId) {
    throw 'Wrong target or missing capacity assignment.'
}
$connection = Invoke-FabricJson @('-X', 'get', "workspaces/$testWorkspaceId/git/connection")
if ($connection.gitConnectionState -ne 'NotConnected') { throw 'Test must not be Git-connected.' }

function Get-TestRoles {
    $token = $null
    do {
        $arguments = @('-X', 'get', "workspaces/$testWorkspaceId/roleAssignments")
        if ($token) { $arguments += @('-P', "continuationToken=$token") }
        $page = Invoke-FabricJson $arguments
        $page.value
        $token = $page.continuationToken
    } while ($token)
}
$assignment = @(Get-TestRoles | Where-Object { $_.principal.id -eq $spObjectId })
if ($assignment.Count -gt 1) { throw 'Unexpected duplicate workspace assignment.' }
if ($assignment.Count -eq 0) {
    $body = @{
        principal = @{ id = $spObjectId; type = 'ServicePrincipal' }
        role = 'Contributor'
    } | ConvertTo-Json -Depth 4 -Compress
    Invoke-FabricJson @('-X', 'post', "workspaces/$testWorkspaceId/roleAssignments", '-i', $body)
} elseif ($assignment[0].role -ne 'Contributor') {
    throw 'Existing role differs; review it instead of silently changing access.'
}
$verified = @(Get-TestRoles | Where-Object {
    $_.principal.id -eq $spObjectId -and $_.role -eq 'Contributor'
})
if ($verified.Count -ne 1) { throw 'Test Contributor grant was not verified.' }

$variables = @{
    AZURE_TENANT_ID = $tenantId
    AZURE_CLIENT_ID = $clientId
    FABRIC_TEST_WORKSPACE_ID = $testWorkspaceId
    FABRIC_DEV_WORKSPACE_ID = $devWorkspaceId
    FABRIC_DEV_LAKEHOUSE_ID = $devLakehouseId
    FABRIC_DEV_MODEL_ID = $devModelId
}
Invoke-Checked gh @('variable', 'list', '--repo', $repo)
# Review existing values before setting or updating this named set.
foreach ($name in $variables.Keys) {
    Invoke-Checked gh @('variable', 'set', $name, '--repo', $repo, '--body', $variables[$name])
}
Invoke-Checked gh @('variable', 'list', '--repo', $repo)
```

These are **non-secret repository variables**, not GitHub secrets or committed configuration.
There is no `AZURE_SUBSCRIPTION_ID`, client secret, or deployment GitHub PAT. The Git credential
used by Dev's Fabric Git integration is separate from this Entra deployment identity.

</details>

Before continuing, have Copilot verify the recorded IDs, trust, Test role, and admin confirmation.
If directory/group changes are still propagating, report that condition and retry the specific
check later; do not create duplicate apps or broaden roles.

## 5. Bootstrap Test's data layer once

The first complete release needs Test tables to exist before the Direct Lake model is published.
This is **one-time data preparation**, not a second implementation of the solution:

```
From the clean, reviewed main checkout, confirm the Test fixture and publisher
setup PR is merged. Using my interactive Azure CLI identity in the correct
tenant, run scripts/deploy_workspace.py --data-only against Contoso Sales Test.
Show the target and commands before publishing. Use the existing Lakehouse and
notebook definitions from Git, not new transformation code.

Using Fabric MCP, upload data/raw/sales-test.csv into Test's ContosoSalesLH at
Files/contoso/raw/sales.csv. Verify path, size, and contents against the local
Test fixture. Do not upload the Dev fixture or copy data from Dev.

Verify the deployed notebook's default Lakehouse is Test's ContosoSalesLH.
Use the Fabric notebook tools/extension to run it there; poll the run to
completion and report errors. In MSSQL, connect to Test's SQL endpoint and
reuse Step 6's validation queries with the Test expectations in the appendix.
Do not publish or refresh the semantic model until these checks pass.
```

With the verified values from setup, Copilot runs the publisher locally like this. Use a
**Python 3.13 project environment**; do not change the globally installed `fab` environment:

```powershell
if (-not (Test-Path -LiteralPath '.\.venv\Scripts\python.exe')) {
    Invoke-Checked py @('-3.13', '-m', 'venv', '.venv')
}
Invoke-Checked '.\.venv\Scripts\python.exe' @('-c',
    'import sys; sys.exit(0 if sys.version_info[:2] == (3, 13) else "Use a Python 3.13 project environment.")')
Invoke-Checked '.\.venv\Scripts\python.exe' @('-m', 'pip', 'install',
    '--requirement', '.\scripts\requirements.txt')
$env:AZURE_TENANT_ID = $tenantId
$env:FABRIC_TEST_WORKSPACE_ID = $testWorkspaceId
$env:FABRIC_DEV_WORKSPACE_ID = $devWorkspaceId
$env:FABRIC_DEV_LAKEHOUSE_ID = $devLakehouseId
$env:FABRIC_DEV_MODEL_ID = $devModelId
Invoke-Checked '.\.venv\Scripts\python.exe' @('.\scripts\deploy_workspace.py', '--data-only')
```

Reuse a compatible existing project environment rather than recreating it. Stop if an install,
authentication, publish, upload, or run fails. SQL metadata can lag notebook completion; refresh
the endpoint metadata/check again, rather than creating duplicate tables.

**Verify in VS Code:** Fabric explorer shows Test's Lakehouse/notebook; the notebook output and
MSSQL checks show `FactSales` **7**, `DimDate` **423**, `DimCustomer` **4**, `DimProduct` **3**,
`DimRegion` **2**, Revenue **22,200**, Cost **15,600**, and Margin **6,600**, with zero missing
dimension keys. Dev still has Revenue **11,100**. Only then enable the complete release.

## 6. Ask Copilot to enable main-to-Test deployment

```
Test's data-layer bootstrap and SQL checks have passed. Create a follow-up
deploy/test-workflow branch from current main and generate deploy.yml using
the workflow below. Keep the reviewed publisher/parameters from the setup PR.

Use main-bound OIDC, no GitHub environment, no stored secret, and no Azure
subscription role. Validate both fixtures and the definitions before login.
Serialize Test deployments without canceling an in-flight publish. Manual
dispatch must only deploy main. Do not upload data or run Spark in this workflow.

Open a PR, explain the changes, and stop for review. After approval and passing
checks, merge it. Use the GitHub Actions extension/tools to inspect that merge's
deployment, report its commit SHA and result, and investigate any failure.
```

{% raw %}
```yaml
name: Deploy Fabric solution to Test

on:
  push:
    branches:
      - main
  workflow_dispatch:

permissions:
  contents: read

concurrency:
  group: fabric-test-deployment
  cancel-in-progress: false

jobs:
  deploy-test:
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write
    env:
      AZURE_TENANT_ID: ${{ vars.AZURE_TENANT_ID }}
      FABRIC_TEST_WORKSPACE_ID: ${{ vars.FABRIC_TEST_WORKSPACE_ID }}
      FABRIC_DEV_WORKSPACE_ID: ${{ vars.FABRIC_DEV_WORKSPACE_ID }}
      FABRIC_DEV_LAKEHOUSE_ID: ${{ vars.FABRIC_DEV_LAKEHOUSE_ID }}
      FABRIC_DEV_MODEL_ID: ${{ vars.FABRIC_DEV_MODEL_ID }}

    steps:
      - name: Check out reviewed source
        uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.13"
          cache: pip
          cache-dependency-path: scripts/requirements.txt

      - name: Install pinned dependencies
        run: python -m pip install --requirement scripts/requirements.txt

      - name: Validate source
        run: |
          python scripts/validate_demo_data.py
          python scripts/validate_demo_data.py --environment test
          python scripts/validate_fabric_definitions.py src/fabric

      - name: Sign in with OIDC
        uses: azure/login@v2
        with:
          client-id: ${{ vars.AZURE_CLIENT_ID }}
          tenant-id: ${{ vars.AZURE_TENANT_ID }}
          allow-no-subscriptions: true

      - name: Verify target and publish definitions
        run: python scripts/deploy_workspace.py
```
{% endraw %}

The merge adding this workflow triggers the first full release. For a later retry, ask Copilot
to dispatch **`main`**, not the development branch. Do not run a local publisher while Actions is
deploying to the same workspace; the workflow concurrency group only serializes Actions runs.

**Protect the review boundary.** Configure the repository's available branch rules so changes to
`main` require the intended PR review and validation checks, and restrict bypass/direct pushes.
OIDC verifies the repository/branch identity, **not** whether a PR was approved. If your private-repo
plan cannot enforce those rules, disclose that limitation rather than claiming enforced approval.

**Future production option:** a protected GitHub environment can add a separate deployment approval
and environment-specific variables. That changes the OIDC subject to an environment subject and
requires explicit deployment-branch restrictions; merely adding `environment:` is not an approval
gate. Private-repository protection features depend on the
[GitHub plan](https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments).
This tutorial does not create a production workspace or require that additional gate.

## 7. Verify the release, not just the job status

```
Inspect the completed main-to-Test GitHub Actions run and report its commit SHA.
Using Fabric MCP, compare Contoso Sales Test with the reviewed src/fabric items:
the Lakehouse, transformation notebook, Contoso Sales semantic model and report.
Report missing/extra items and confirm Test is still not Git-connected.

Inspect the notebook's Lakehouse binding, the model's actual OneLake source and
data connection, and the report's semantic-model reference. All must point to
Test items, not Dev; do not infer correctness from identical item names.

Using the Modeling MCP connected specifically to Test, refresh/reframe the model
after checking its connection permissions, then query its existing measures.
Expect Revenue 22,200, Cost 15,600, Margin 6,600 and 7 fact rows. Reuse the other
Step 7 checks with the appendix's Test values. Verify Dev still returns its
original 11,100 / 7,800 / 3,300 totals.

Open the deployed Test report from Fabric explorer and check the displayed values
and model binding. Preserve the Dev-bound local PBIR project. Report findings;
do not delete, silently rebind to Dev, or repair items without approval.
```

Opening the deployed report can launch the Fabric browser experience; the VS Code extension is
not a replacement report renderer. The PBIR/Desktop Bridge authoring loop from Step 8 remains
unchanged. If a model refresh fails for credentials, stop and have its owner configure the
Test data connection/permissions; a successful deployment does not transfer those credentials.

The release is ready only when the item inventory, bindings, SQL/DAX results, and report agree.
In particular, unchanged percentage measures alone cannot distinguish these two datasets.

### After the first release

- Ordinary merges publish definitions; they do not re-upload the fixture or automatically run
  Spark. Test's existing data stays in its own Lakehouse.
- A changed fixture requires an intentional Test restage and refresh. Step 11 adds the scheduled
  notebook/model refresh over that landed data, not an imaginary source-system ingestion.
- Table/schema-changing releases may need a coordinated migration/notebook run **before** dependent
  model publication. Plan that explicitly; do not apply the report-only release sequence blindly.
- A `401`/OIDC subject mismatch is an authentication problem; a Fabric `403` calls for checking the
  tenant setting, principal object ID, and Test role. Do not fix either by granting broad Azure roles.

## What to notice

- Deployment starts from **reviewed source**, not an untracked desktop file.
- Copilot reused your earlier work and drove the setup, PR, deployment, and verification through
  the same VS Code tools; the learner still reviews changes and grants approvals.
- Git sync supports **development**. Deployment promotes definitions into **Test**. Data refresh
  executes those definitions against **Test's own data**.
- Identity and permissions remain those of the configured user or automation principal.

Next: [Step 11 — Orchestrate the Test refresh](11-orchestrate.md).
