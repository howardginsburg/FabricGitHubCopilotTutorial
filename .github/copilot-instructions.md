# Copilot instructions — Fabric + Power BI tutorial

You are helping a developer work through a tutorial that builds a Microsoft Fabric and Power BI
solution end to end with GitHub Copilot. This file tells you what tooling exists on this
workstation and which tool to use for each kind of task. It is loaded automatically in VS Code
Copilot Chat and the GitHub Copilot CLI, so rely on it rather than guessing.

## Environment (installed by scripts/setup.ps1)

These command-line tools are installed for the workstation and available in any folder. Assume
they exist and use them; do not claim you lack the ability to run them after only checking the
current process PATH.

- `fab` — the **Microsoft Fabric CLI**. Your primary tool for **workspace and capacity**
  operations and for OneLake file transfer.
- `az` — Azure CLI. Used for Azure-level operations (including creating a Fabric capacity, if
  ever needed).
- `gh` — GitHub CLI. Used for repositories, branches, and pull requests.
- `dotnet` / `dnx` — .NET 10 SDK, used to run the Data Factory MCP.

`fab` is installed with pipx. On Windows, a long-running VS Code process may have a stale PATH
after setup even though `fab` is installed. If `Get-Command fab` fails:

1. Refresh the shell PATH from the persisted machine and user values:

   ```
   $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
       [Environment]::GetEnvironmentVariable('Path', 'User')
   ```

2. Retry `Get-Command fab`.
3. If it is still unavailable, check `$HOME\.local\bin\fab.exe` and invoke that executable
   directly. Do not reinstall the CLI, alter its pipx environment, or fall back to another API
   solely because the current process PATH is stale.

The user signs in interactively with `az login`, `gh auth login`, and `fab auth login`. Check
`fab auth status` before Fabric operations. `fab auth login` requires a real Windows console and
can fail with `No Windows console found` in a redirected agent shell; have the user run it in an
interactive terminal or open a visible Command Prompt for them. Never collect or manage
credentials yourself.

You may run these shell commands to accomplish the user's Fabric and GitHub tasks. Show the
command and, for anything that creates or changes cloud resources, briefly say what it will do
before running it.

## Which tool for which job

Route each task to the correct tool. This matters because the MCP servers below do **not** cover
everything:

- **Create a Fabric workspace / assign a capacity / list capacities** → use the **`fab` CLI**.
  Do not use the Fabric MCP, Azure REST API, `az rest`, or Power BI Modeling MCP for these
  operations. Use this idempotent sequence:

  ```
  fab auth status
  fab exists "Name.Workspace"
  fab ls .capacities
  fab mkdir "Name.Workspace" -P capacityName=CapacityName  # only when exists returned False
  fab assign ".capacities/CapacityName.Capacity" -W "Name.Workspace"  # existing workspace only
  fab exists "Name.Workspace"
  fab get "Name.Workspace" -q .
  fab get ".capacities/CapacityName.Capacity" -q .
  fab ls "Name.Workspace"
  ```

  Confirm the requested capacity appears before creation or assignment. In the final output,
  require `capacityAssignmentProgress` to be `Completed`, compare the workspace `capacityId` with
  the capacity `fabricId`, and report the workspace `id`. When the request says not to create
  items, confirm the final workspace listing is empty.
- **Create or change items inside an existing workspace** (Lakehouse, notebook, OneLake files,
  Data Factory items) → prefer the **Fabric MCP** in VS Code Agent mode (for example
  `core_create-item`, the `onelake_*` tools). The `fab` CLI can also do these.
- **Author or validate a semantic model** (relationships, measures, DAX) → use the **Power BI
  Modeling MCP** against the workspace semantic model (Direct Lake; XMLA endpoint).
- **Orchestrate/schedule pipelines** (Dataflows Gen2, Copy Jobs, pipelines) → use the **Data
  Factory MCP** (preview).
- **Ground platform-specific claims** → use the **Microsoft Learn MCP**.
- **Repositories, branches, pull requests** → use the **`gh` CLI** or the GitHub tools.
- **Connect a workspace to GitHub (Fabric Git integration)** → use **`fab api`** (see
  [Connect a workspace to GitHub](#connect-a-workspace-to-github-fabric-git-integration) below).
  No MCP exposes Git integration; do not use the Fabric MCP or `az rest` for it.

A **Fabric capacity is an Azure resource** (or a Fabric trial). Do not try to "create a
capacity" through `fab` or an MCP; assume the user already has one and only **assign** the
workspace to it. If no capacity exists, direct the user to create one in the Azure portal or a
Fabric trial.

## Connect a workspace to GitHub (Fabric Git integration)

GitHub Git integration is a **`fab api`** workflow — no MCP tool covers it. Run this exact sequence,
show each call, and don't improvise a different API. The workspace must already be assigned to a
capacity.

1. **Get a GitHub PAT interactively.** A PAT can't be minted headlessly (GitHub requires
   password/2FA), so open the pre-filled classic-token page for the user and have them paste it
   back: `https://github.com/settings/tokens/new?scopes=repo` (classic, `repo` scope). Use the
   token only in the connection body below — never write it to a file or commit. Recommend a short
   expiry and revoking it when done.

2. **Create a `GitHubSourceControl` connection**, scoped to the repo URL. Pass the body inline with
   `-i` (a JSON string), so the PAT never touches disk:

   ```
   $body = @{
     connectivityType  = 'ShareableCloud'
     displayName       = '<repo>-git'
     connectionDetails = @{
       type           = 'GitHubSourceControl'
       creationMethod = 'GitHubSourceControl.Contents'
       parameters     = @(@{ dataType='Text'; name='url'; value='https://github.com/<owner>/<repo>' })
     }
     credentialDetails = @{ credentials = @{ credentialType='Key'; key=$pat } }
   } | ConvertTo-Json -Depth 6
   fab api -X post connections -i $body      # capture the returned connection id
   ```

3. **Pre-create the target Git folder on the branch — the critical gotcha.** Unlike the portal, the
   connect API returns a misleading `GitProviderResourceNotFound` if the directory (e.g.
   `src/fabric`) does not already exist on the branch. Commit a placeholder first — PUT
   `repos/<owner>/<repo>/contents/src/fabric/.gitkeep` via the GitHub Contents API with `branch`
   set. A `.gitkeep` placeholder is not a Fabric item, so this honors a "don't commit items yet"
   request.

4. **Connect the workspace.** GitHub uses `ownerName` (not `organizationName`):

   ```
   $body = @{
     gitProviderDetails = @{
       ownerName='<owner>'; gitProviderType='GitHub'; repositoryName='<repo>'
       branchName='<branch>'; directoryName='<folder>'
     }
     myGitCredentials = @{ source='ConfiguredConnection'; connectionId='<id from step 2>' }
   } | ConvertTo-Json -Depth 6
   fab api -X post "workspaces/<workspace-id>/git/connect" -i $body
   ```

5. **Initialize the connection** to set the sync baseline:

   ```
   fab api -X post "workspaces/<workspace-id>/git/initializeConnection" -i '{"initializationStrategy":"PreferRemote"}'
   ```

   With both sides empty this returns `requiredAction: None`.

6. **Verify:** `fab api -X get "workspaces/<workspace-id>/git/connection"` should report
   `gitConnectionState: ConnectedAndInitialized`. Delete any extra connections you created while
   troubleshooting.

### `fab api` notes

- `-X` methods are lowercase: `get`, `post`, `put`, `patch`, `delete`.
- `-i` is the request body and accepts an **inline JSON string** (build it with `ConvertTo-Json`);
  a file is not required, which keeps secrets off disk.
- `-q` is a **JMESPath** filter — omit it unless you have a valid JMESPath expression (an invalid
  one errors and can mask whether the call itself succeeded).

## Surfaces

- **VS Code Copilot Chat (Agent mode)** has the Fabric MCP, Power BI Modeling MCP, Microsoft
  Learn MCP, and (once registered) the Data Factory MCP. Prefer MCP tools for item-level work.
- **The standalone `copilot` CLI** does not have the VS Code Fabric MCP. There, drive Fabric by
  running `fab` shell commands.

In both surfaces, use the `fab` CLI for workspace and capacity operations.

## Ways of working

- Inspect before you create: check for existing workspaces, items, and name conflicts first.
- Plan before using write-capable tools; show the proposed change before applying it.
- Validate results (row counts, SQL/DAX totals) rather than trusting a success status.
- Never commit secrets or environment-specific workspace or capacity IDs.
- Never write GitHub PATs or other secrets to files or commits; store them only in a Fabric
  connection, and prefer short-lived, repo-scoped tokens.
