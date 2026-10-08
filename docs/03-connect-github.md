---
title: 3. Connect the workspace to GitHub
nav_order: 4
---

# Step 3 — Connect the workspace to GitHub

**Goal:** create a **new, empty** solution repository and connect your **blank** Fabric
workspace to it with **Fabric Git integration**. Both start empty — the whole point is to
watch the solution's source files appear as you build.

**What Copilot uses:** the **`gh` CLI** to create the repo and **Fabric's Git integration APIs**
(`fab api`) to connect the workspace. GitHub Git integration is a `fab api` operation — the Fabric
MCP doesn't expose it — so the agent scripts the whole connection for you.

> **Two repositories, don't mix them up.** The repo you're reading this tutorial from
> (`docs/`, `scripts/setup.ps1`) is the **tutorial**. The repo you create below is the
> **solution** repo — it holds only the Fabric item definitions the workspace commits. Do
> **not** push the tutorial into it.

## Create the empty solution repository

Ask Copilot to create the repo and working branch:

```
Create a private GitHub repo named contoso-sales-fabric with a README, cloned
beside my current tutorial folder (not inside it), then add and push a
build/contoso-sales branch.
```

Copilot runs `gh` and `git` for you and shows the commands:

```
gh repo create contoso-sales-fabric --private --add-readme --clone
cd contoso-sales-fabric
git switch -c build/contoso-sales
git push -u origin build/contoso-sales
```

> **Where the clone lands.** `--clone` checks the repo out into the **current** folder, so tell
> Copilot to place it **beside** the tutorial repo, not inside it. You want siblings:
>
> ```text
> Prototypes/
> ├── FabricGitHubCopilotTutorial/   # tutorial repo (currently open)
> └── contoso-sales-fabric/      # solution repo created here
> ```

The `build/contoso-sales` branch now contains only the stub `README.md`; `src/fabric/` does not
exist yet. There is no Fabric solution source — that is expected.

## Connect the workspace to the repo

With the **tutorial** folder still open (so Copilot has the `fab` routing instructions), ask:

```
Connect my "Contoso Sales Dev" Fabric workspace to the contoso-sales-fabric repo
on the build/contoso-sales branch, using src/fabric as the Git folder. Don't
commit any items yet — I just want the connection established.
```

### What Copilot does

Fabric's GitHub Git integration is driven through `fab api`, and the agent runs the full sequence,
showing each call:

1. **Gets you a GitHub token.** A Personal Access Token can't be minted non-interactively, so
   Copilot opens the pre-filled
   [token page](https://github.com/settings/tokens/new?scopes=repo) (classic, `repo` scope) for you
   to generate one and hand back.
2. **Creates a GitHub credential connection.** Fabric stores your credential as a *connection* and
   the connect API references it by ID. Copilot creates a `GitHubSourceControl` connection scoped
   to your repo:

   ```
   fab api -X post connections -i '<connection body with your PAT>'
   ```

3. **Seeds the target folder.** Unlike the portal, the connect API fails with a misleading
   `GitProviderResourceNotFound` if the Git folder doesn't already exist on the branch. So Copilot
   first commits a tiny `src/fabric/.gitkeep` placeholder (via the GitHub API) so `src/fabric`
   exists.
4. **Connects the workspace** to the repo, branch, and folder, referencing the connection ID:

   ```
   fab api -X post "workspaces/<workspace-id>/git/connect" -i '<connect body>'
   ```

   The body carries `ownerName`, `repositoryName`, `branchName` (`build/contoso-sales`),
   `directoryName` (`src/fabric`), and `myGitCredentials` referencing the connection.
5. **Initializes the connection** to set the sync baseline:

   ```
   fab api -X post "workspaces/<workspace-id>/git/initializeConnection" -i '{"initializationStrategy":"PreferRemote"}'
   ```

   With both sides empty, this returns `requiredAction: None` — nothing to commit.

> **Token hygiene.** The PAT is a secret. Use a **short-lived, repo-scoped** classic token; let
> Copilot store it **only** in the Fabric connection (never in a file or commit); and **revoke it**
> at <https://github.com/settings/tokens> when the connection is no longer needed. An active
> connection still needs a valid credential for later syncs. If a token is ever pasted into chat,
> treat it as exposed and rotate it.

## Verify

Copilot confirms the connection is live. Check it directly with your workspace ID:

```
$ws = "<workspace-id>"
fab api -X get "workspaces/$ws/git/connection"
```

- `gitConnectionState` is **`ConnectedAndInitialized`**, with `gitProviderDetails` showing the
  repo, `build/contoso-sales`, and `/src/fabric`.
- The workspace **Source control** panel shows `contoso-sales-fabric` on `build/contoso-sales`.
- Apart from the `src/fabric/.gitkeep` placeholder, the branch has **no item content yet** — it
  stays that way until you create items in [Step 6](06-build-data-path.md). You can delete
  `.gitkeep` after the first real commit.

> **Connected does not mean automatically synchronized.** Workspace edits reach the branch when
> you **Commit** in Fabric Source control. Changes pushed to `src/fabric` reach live Dev items
> only after **Source control → Updates → Update all**, or an explicit `updateFromGit` operation.
> This tutorial does not configure automatic Git-to-Dev updates. Local `git pull` updates your
> clone, not the workspace; switching the local branch does not switch Fabric's connection.
> See [Microsoft's update workflow](https://learn.microsoft.com/fabric/cicd/git-integration/git-get-started#update-workspace-from-git).

Next: [Step 4 — Open the solution and add Copilot instructions](04-clone-and-open.md).
