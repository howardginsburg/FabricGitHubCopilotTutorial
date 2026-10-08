---
title: 2. Create a Fabric workspace
nav_order: 3
---

# Step 2 — Create a Fabric workspace

**Goal:** create a dedicated, disposable **development** workspace and assign it to an existing
Fabric capacity. Never use a production workspace for this tutorial.

**What Copilot uses:** the **`fab` CLI**. Workspace creation and capacity assignment are `fab`
operations — the Fabric MCP only acts on items *inside* an existing workspace, so the agent reaches
for `fab` here, not an MCP.

> **You need a capacity first.** A Fabric *capacity* is an Azure resource (or a
> [Fabric trial](https://learn.microsoft.com/fabric/fundamentals/fabric-trial)). Copilot does
> **not** create one — neither `fab` nor any MCP does — it only **assigns** your workspace to a
> capacity you already have. If `fab ls .capacities` shows none, start a Fabric trial or create a
> capacity in the Azure portal first.

## Ask Copilot

In VS Code Copilot Chat (**Agent mode**), with this tutorial folder open so
`.github/copilot-instructions.md` loads, ask:

```
Using the fab CLI, create a Fabric development workspace named
"Contoso Sales Dev" and assign it to the "centralfabriccapacity" capacity.
Confirm the workspace exists and report its ID. Do not create any items yet.
```

## What Copilot does

Copilot follows the routing in `.github/copilot-instructions.md` and drives the `fab` CLI for you.
Approve the commands when prompted. Under the hood it runs an idempotent sequence:

1. **Confirms it can reach `fab`.** The Fabric CLI is installed globally with pipx. A long-running
   VS Code process can hold a stale `PATH`, so if `fab` isn't found the agent refreshes the
   environment from the persisted `PATH` (or calls `%USERPROFILE%\.local\bin\fab.exe` directly)
   instead of reinstalling anything.
2. **Checks you're signed in** with `fab auth status`. If not, it asks you to run `fab auth login`
   in a real terminal window — that interactive login needs a Windows console and fails in a
   redirected shell.
3. **Confirms the capacity exists and the workspace doesn't:**

   ```
   fab ls .capacities
   fab exists "Contoso Sales Dev.Workspace"
   ```

4. **Creates and assigns in one step.** In `fab` 1.7 the capacity is a creation parameter, so
   `mkdir` both creates the workspace and assigns the capacity:

   ```
   fab mkdir "Contoso Sales Dev.Workspace" -P capacityName=centralfabriccapacity
   ```

   If the workspace already existed, the agent instead assigns the capacity with
   `fab assign ".capacities/centralfabriccapacity.Capacity" -W "Contoso Sales Dev.Workspace"`.

> Tip: `fab config set mode interactive` gives a shell-like experience (`cd`, `ls`, tab
> completion) if you ever want to explore the tenant yourself.

## Verify

Copilot reports the workspace **ID** and confirms the capacity assignment. It — and you — can
double-check the same way:

```
fab exists "Contoso Sales Dev.Workspace"                       # true
fab get "Contoso Sales Dev.Workspace" -q .                     # full workspace properties
fab get ".capacities/centralfabriccapacity.Capacity" -q .      # capacity properties
fab ls "Contoso Sales Dev.Workspace"                            # empty before creating items
```

Confirm `capacityAssignmentProgress` is `Completed`, and that the workspace's `capacityId` matches
the capacity's `fabricId`. Note this **Dev** workspace `id` for Git integration and authoring.
[Step 10](10-deploy.md) creates a separate **Test** deployment target; do not use the Dev ID as
that target. An empty `ls` result confirms this step created no items.

Next: [Step 3 — Connect the workspace to GitHub](03-connect-github.md).
