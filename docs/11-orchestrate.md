---
title: 11. Orchestrate the Test refresh
nav_order: 12
---

# Step 11 — Orchestrate the Test refresh

**Goal:** turn the deployed pieces into a **scheduled Test** refresh. Build a Fabric Data
Factory pipeline that runs the transformation notebook and then refreshes the semantic model, on
a schedule — and keep that pipeline in source control like everything else. This is the
**operate** phase of the lifecycle.

**What Copilot uses:** Copilot + the **Microsoft Data Factory MCP** (preview).

Author the pipeline in **Dev**, review its definition, and deploy it into **Test** through the
workflow from Step 10. Run and schedule the **Test copy**, not the Dev authoring copy. The pipeline
reuses the CSV already landed in each environment; source-system ingestion is still simulated,
not a hidden third activity.

> The [Data Factory MCP](https://github.com/microsoft/DataFactory.MCP) is a preview,
> Microsoft-owned MCP server for Fabric Data Factory. It exposes tools to list, create, update,
> run, monitor, and **schedule** pipelines, Dataflows Gen2, and Copy Jobs. It is distributed as a
> NuGet package and run with `dnx`, so it is registered per workspace rather than by
> `scripts/setup.ps1`.

## Enable the Data Factory MCP

This server is registered in the **solution repo** so Copilot can use it there.

1. Ensure the **.NET 10 SDK** is installed — it provides the `dnx` command that runs the server.
   [`scripts/setup.ps1`](01-environment-setup.md) already installs it during workstation setup;
   if you skipped that or are on a fresh machine, install it with:

   ```
   winget install --id Microsoft.DotNet.SDK.10 --exact
   ```

2. In the solution repo, create `.vscode/mcp.json` (check the
   [NuGet package page](https://www.nuget.org/packages/Microsoft.DataFactory.MCP) for the
   current version and replace `#{VERSION}#`):

   ```
   {
     "servers": {
       "DataFactory.MCP": {
         "type": "stdio",
         "command": "dnx",
         "args": [
           "Microsoft.DataFactory.MCP",
           "--version",
           "#{VERSION}#",
           "--yes"
         ]
       }
     }
   }
   ```

3. Reload VS Code (or start the server from **MCP: List Servers**). In Copilot Chat (Agent
   mode), confirm the Data Factory tools appear in the **tools** list, then authenticate:

   ```
   Using the Data Factory MCP tools, authenticate to Fabric interactively,
   then confirm and report my authentication status (signed-in account and
   tenant) before we build any pipeline.
   ```

## Do it — build the orchestration pipeline

First, bring the development branch up to date with the release setup you merged in Step 10.
The local clone may currently be on `main`, while Fabric Dev is still connected to
`build/contoso-sales`. Ask Copilot:

```
Prepare for the next change on build/contoso-sales. Inspect local git status and
the Dev workspace's Git status first. Preserve outstanding work and stop for
conflicts; do not reset, force-push, or switch Fabric's connected branch.

Once clean, fetch main, switch the local clone to build/contoso-sales, merge
origin/main, and push. Inspect incoming Fabric item changes and explicitly
update Dev from Git if needed, using current heads and polling completion.
Confirm Dev's item changes are resolved before creating the pipeline.
```

Ask Copilot to build a pipeline in the **Contoso Sales Dev** workspace that chains the two
refresh activities:

```
Using the Data Factory MCP, create a pipeline named "Refresh Contoso Sales" in
the "Contoso Sales Dev" workspace with two activities:
1. A notebook activity that runs the existing transformation notebook which
   builds the star-schema Delta tables (FactSales and the four dimensions).
2. A semantic-model refresh activity that refreshes the "Contoso Sales"
   semantic model.

Make activity 2 depend on activity 1 succeeding (run the refresh only on
success). Reuse existing items — do not create a duplicate notebook or model.
Show the full pipeline definition and let me approve it before you create it.
Do not enable a schedule in Dev.
```

## Source-control the pipeline

The pipeline is a Fabric item, so it belongs in Git like the rest of the solution. As with the
notebook and model, **Fabric Git integration** captures the workspace definition; `git add` alone
does not export it. Ask Copilot:

```
Inspect Dev's Git status, then commit the approved "Refresh Contoso Sales"
pipeline through Fabric Git integration to build/contoso-sales. Poll the
operation and verify Git status, then pull the exported definition locally.
Do not commit unrelated workspace changes or resolve conflicts by overwriting.

Check the DataPipeline folder under src/fabric has pipeline-content.json and
.platform. Extend the existing definitions validator with that item type,
preserving its earlier checks. The Step 10 publisher already includes
DataPipeline: inspect the activity workspace, notebook, model and connection
references and extend parameter.yml for any object IDs needing Test mappings.
Use dynamic references to the deployed items, not committed Test GUIDs.

Inspect any .schedules definition: no enabled Dev schedule should be promoted.
Stage only the validator/parameter/instruction changes still local (the pipeline
definition is already committed), review the full branch diff, and open a PR to
main. Stop for review, then merge only after approval and passing checks.
Inspect the main-to-Test Actions deployment and report its commit SHA/result.
```

Review the readable pipeline diff in **GitHub Pull Requests**, then inspect the deployment in
**GitHub Actions**. Verify the deployed Test pipeline references Test's notebook and semantic model.
Connection IDs and runtime permissions need their own verification: deployment OIDC is not a
source/refresh credential. If an activity needs a Fabric connection, have its authorized owner
configure/share the Test connection before running it.

## Run and schedule the deployed Test pipeline

First, ask Copilot to run **Test's** pipeline once and inspect both activities and the Test totals.
Only after that run succeeds, put the **Test copy** on a schedule:

```
Using the Data Factory MCP, create or update a schedule for "Refresh Contoso Sales"
in "Contoso Sales Test" that runs once daily at 06:00. Ask me to confirm the
explicit time zone before enabling it. Inspect existing schedules first; reuse
the intended one rather than creating duplicates. Do not schedule the Dev copy.
Then report frequency, time, time zone, enabled state, and the next run time.
```

Fabric can serialize pipeline schedules in a **`.schedules`** definition; see
[pipeline CI/CD](https://learn.microsoft.com/fabric/data-factory/cicd-pipelines#scheduled-pipeline-cicd-integration).
Here, activation is an explicit Test operation after validation. Inspect the pinned publisher's
handling of any schedule definition and recheck Test's schedule after redeployment; do not assume
either that Git always carries activation or that schedules can never be source-controlled.

## Verify

Run the pipeline once on demand and confirm it succeeds end to end:

```
Using the Data Factory MCP, run "Refresh Contoso Sales" in "Contoso Sales Test" and
report the run status of each activity (notebook run, then model refresh),
including start/end and any error. Then list the pipeline's schedules and
confirm the daily schedule is enabled with its next run time.
Verify Test's SQL/model totals remain Revenue 22,200, Cost 15,600, Margin 6,600.
Confirm no Dev schedule was enabled and Dev still has its original totals.
```

You should see:

- Both activities (notebook run, then model refresh) complete successfully.
- The daily schedule listed and enabled in **Test**, with the intended time zone.
- The pipeline definition present in `src/fabric/` under source control.
- Test-specific bindings and results match the [Test expectations](reference.md#test-fixture-step-10-onward).

## What to notice

- **Data Factory orchestrates** the moving parts — notebook plus model refresh — as one
  governed, scheduled unit, instead of running each by hand.
- Copilot drove a **third first-party MCP** here (Data Factory), alongside the Fabric and Power
  BI Modeling MCPs — same agent, different tools for a different job.
- Even the operational pipeline is **source-controlled and reviewable**, closing the loop: plan,
  build, validate, review, deploy, and now operate.

Next: [Step 12 — Consume the solution](12-consume.md).
