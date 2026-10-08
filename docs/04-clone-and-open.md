---
title: 4. Open the solution and add Copilot instructions
nav_order: 5
---

# Step 4 — Open the solution and add Copilot instructions

**Goal:** open the solution repo you created in [Step 3](03-connect-github.md), give it its own
Copilot instructions **before asking Copilot to build anything**, then confirm the full agent
toolset — extensions, MCP servers, and skills — is loaded.

**What Copilot uses:** VS Code and Copilot Chat.

## Do it

You already cloned `contoso-sales-fabric` and switched to the `build/contoso-sales` branch in
Step 3. If you are continuing in the same terminal, it should already be in the solution folder;
skip the `cd` command below. From a new terminal opened in the parent folder, run all three
commands. Open the solution in a **new VS Code window**:

```
cd .\contoso-sales-fabric     # skip if the terminal is already here
git switch build/contoso-sales
code .          # or: code-insiders .
```

After the new window opens, use its integrated terminal for all subsequent solution commands.
Confirm the terminal and Git branch before continuing:

```
git rev-parse --show-toplevel
git branch --show-current
```

The first command must point to `contoso-sales-fabric`, not `FabricGitHubCopilotTutorial`; the second
must return `build/contoso-sales`.

> The CLIs, MCP servers, Copilot skills, and VS Code extensions were installed **per machine**
> by `scripts/setup.ps1` in [Step 1](01-environment-setup.md), so they are available here even
> though this is a different repository from the tutorial. You do **not** re-run setup.

## First, give the repo its Copilot instructions

Do this before opening a new Copilot Chat for solution work. Teach Copilot the project's
conventions **once** by
adding a repository instructions file. GitHub Copilot automatically loads
`.github/copilot-instructions.md` as context for every Copilot Chat session in this workspace —
so you don't have to restate the rules in each prompt, and everyone who works in the repo gets
the same behavior. This is the "GitHub-enabled agent workspace" idea made concrete: the repo
carries its own guidance.

Create the file yourself so you understand what it encodes. In the solution VS Code window, use
the Explorer's **New File** action to add `.github/copilot-instructions.md`, then paste:

````
# Copilot instructions — Contoso Sales (Fabric + Power BI)

This repository holds a Microsoft Fabric and Power BI solution: a sales star schema in a
Lakehouse, a Power BI semantic model, and an executive report, deployed through Fabric CI/CD.
Follow these conventions when generating or changing anything here.

## Source layout
- `src/fabric/` — Fabric item definitions synced via Git integration (Lakehouse, Notebook,
  SemanticModel, Report). These are the source of truth; edit definitions, not deployed copies.
- `tests/` — DAX and SQL validation.
- `.github/workflows/` — CI (validation) and CD (deployment).

## Item names
- Workspace: `Contoso Sales Dev`.
- Lakehouse: `ContosoSalesLH` — Lakehouse names cannot contain spaces, so use this exact name (not
  "Contoso Sales").
- Semantic model and report: `Contoso Sales` — these allow spaces.
- Reuse existing items with these names; never create duplicates.

## Workstation tools
- `fab` is installed globally with pipx. Use it for workspace/capacity operations, OneLake file
  transfer, and Fabric Git integration (`fab api`); do not substitute `az rest` or the Fabric MCP
  for these.
- On Windows, if `Get-Command fab` fails, refresh `$env:Path` from the persisted Machine and User
  PATH values, then retry. If needed, invoke `$HOME\.local\bin\fab.exe` directly; do not reinstall
  the pipx environment solely because the VS Code process has a stale PATH.
- Check `fab auth status` before Fabric operations. Run `fab auth login` in a real terminal window
  if required; redirected agent shells may not provide the Windows console that login needs.
- `fab api` mechanics: methods are lowercase (`get`, `post`, `put`, `patch`, `delete`); `-i` takes
  an inline JSON string (build it with `ConvertTo-Json`, keeping secrets off disk); `-q` is a
  JMESPath filter — omit it unless the expression is valid.

## Git integration (fab api)
- GitHub Git integration is a `fab api` workflow; no MCP exposes it. Sequence: create a
  `GitHubSourceControl` connection holding the PAT → `git/connect` → `git/initializeConnection` →
  verify `gitConnectionState` is `ConnectedAndInitialized`.
- Critical gotcha: unlike the portal, `git/connect` fails with a misleading
  `GitProviderResourceNotFound` if the target folder (`src/fabric`) doesn't already exist on the
  branch. Commit a `.gitkeep` placeholder there first (a placeholder is not a Fabric item).
- GitHub uses `ownerName` in `gitProviderDetails` (Azure DevOps uses `organizationName`).
## Source of truth and how items reach `src/fabric/`
- `src/fabric/` is the reviewed, deployable mirror; fabric-cicd publishes reviewed `main` to the
  separate Test workspace introduced in Step 10, not back into Git-connected Dev. Items
  reach it two ways depending on how they're authored — never both for the same item:
  - **Workspace-native items (Lakehouse, notebook, Direct Lake semantic model, pipeline):** created
    and authored in the **workspace** (notebook in the Fabric extension/editor; model via the Power
    BI Modeling MCP against the workspace model). Capture via **Fabric Git integration**: commit the
    workspace (`git/status` → `git/commitToGit` mode `All`, portal Source control panel or `fab api`),
    then `git pull`. The workspace showing them "uncommitted" is expected until you commit. In Git a
    notebook is a `<Name>.Notebook/` folder (`notebook-content.py` + `.platform`, not `.ipynb`); a
    semantic model is a `<Name>.SemanticModel/` folder (`definition.pbism` + `definition/` TMDL +
    `.platform`).
  - **The report (PBIR):** authored **locally** by the `powerbi-authoring` skill under `src/fabric/`,
    bound by connection to the remote Direct Lake model. The local PBIR is the source of truth —
    commit it with **plain `git`** (not Git integration). It's a `<Name>.Report/` folder
    (`definition.pbir` + `definition/` + `.platform`) plus a `<Name>.pbip` manifest.
  - The VS Code Fabric extension/editors run and author items but don't commit workspace items.

## Copilot skills
- The `fabric-skills` and `powerbi-authoring` skills are installed on this workstation and supply
  the *process* for specialized tasks. Prefer them over ad-hoc steps.
- Use `fabric-skills` for Fabric item workflows (Lakehouse/notebook data path, item scaffolding and
  conventions); it guides *how*, while the Fabric MCP and `fab` CLI perform the actions.
- Use `powerbi-authoring` for semantic-model and report work (report planning, design, DAX
  conventions); it pairs with the Power BI Modeling MCP, which makes the model edits.

## Ways of working
- Inspect before you create: search the workspace for existing items and name conflicts first.
- Plan before using write-capable tools; show proposed changes before applying them.
- Ground platform-specific claims in current docs via the Microsoft Learn MCP.
- Route each task to the right layer: a **skill** for process guidance (`fabric-skills`,
  `powerbi-authoring`), an **MCP** or **CLI** for the action. Use the `fab` CLI for workspace and
  capacity operations (the Fabric MCP does not create workspaces); the Fabric MCP for item
  operations within a workspace; the Power BI Modeling MCP for the semantic model; and the Data
  Factory MCP for pipeline orchestration and scheduling.
- Never commit secrets or environment-specific workspace IDs. Never write GitHub PATs to files or
  commits — store them only in a Fabric connection, and prefer short-lived, repo-scoped tokens that
  you revoke when done.

## Data path (notebook)
- Create the transformation notebook **bound to the `ContosoSalesLH` Lakehouse as its default
  Lakehouse**, so relative `Files/...` paths and `saveAsTable` resolve without extra setup.
- Read with an explicit schema and explicit data types (Quantity int; UnitPrice/UnitCost
  decimal(18,2), not double).
- Emit an integer surrogate `DateKey` (yyyyMMdd) on both `FactSales` and `DimDate` as the fact→date
  join key; do not keep `OrderDate` on `FactSales`. `DimDate` also carries a `Date` column (marked
  as the date table, used by time intelligence).
- Reject invalid business keys (nulls, non-positive quantity, negative price or cost); fail loudly.
- Enforce a unique OrderId and consistent dimension attributes.
- Report row counts for every output table. Validate totals with SQL or DAX — a successful job
  status is not proof of correctness.
- Spark registers table names **lowercase** (`factsales`, `dimdate`, …) and the Fabric SQL endpoint
  is **case-sensitive** — reference tables lowercase in SQL (`dbo.factsales`). Column names keep
  their case. In the semantic model, give tables `FactSales`/`DimDate`/… display names (DAX is
  case-insensitive).

## Star schema
- One fact table `FactSales`; dimensions `DimDate`, `DimCustomer`, `DimProduct`, `DimRegion`.
- These are the logical/model table names (the physical Lakehouse tables are the lowercase
  equivalents). In the **semantic model**, use exactly `FactSales`/`DimDate`/`DimCustomer`/
  `DimProduct`/`DimRegion` — do not rename to business-friendly names (no `Sales`/`Date`/`Customer`);
  friendly labels belong on columns and measures. This keeps DAX and the row-count anchors
  consistent.
- Single-direction, one-to-many relationships from each dimension key to `FactSales`.
- Do not relate dimensions to each other.

## Semantic model
- Storage mode is **Direct Lake** — the model reads the Lakehouse Delta tables from OneLake with no
  import/copy. Create it in Fabric (in the workspace, the **…** menu on `ContosoSalesLH` → **New
  semantic model**), named `Contoso Sales`, in the `Contoso Sales Dev` workspace.
- Author it in the workspace with the **Power BI Modeling MCP** connected to the workspace model
  (XMLA), or the web **Open data model** UI. Capture it via **Git integration** (commit → `git pull`)
  as a `Contoso Sales.SemanticModel/` TMDL folder — do not export a local PBIP.
- Prefer measures over calculated columns; calculated columns and most calculated tables aren't
  supported on Direct Lake tables (build `DimDate` as a real Delta table in the notebook, not a DAX
  calculated table).
- Use `DIVIDE()` for ratios, never `/` (it handles divide-by-zero and blanks).
- Give measures format strings, descriptions, and display folders.
- Relationships: single-direction one-to-many from each dimension key to `FactSales`, joining on the
  integer `DateKey`/`*Id` columns (`DimDate[DateKey]`→`FactSales[DateKey]`, etc.).
- Hide technical key columns (all `*Id` and `*Key`, including `DateKey`); keep `DimDate[Date]` visible.
- Mark `DimDate` as the date table using `DimDate[Date]`; sort `MonthName` by `MonthNumber`; disable
  auto date/time.
- After adding relationships to a Direct Lake model, a **Full refresh** may be needed to reframe
  time-intelligence measures.

## Report (PBIR)
- Author the report **locally as PBIR** with the `powerbi-authoring` skill under `src/fabric/`, bound
  by connection to the remote `Contoso Sales` Direct Lake model. Validate with `powerbi-report-author
  validate`; verify rendering in Power BI Desktop via the `powerbi-desktop` Desktop Bridge (open →
  reload → screenshot). Commit the PBIR with **plain `git`** (not Git integration).
- Use explicit model measures in visuals; never create implicit measures or duplicate model
  logic inside a visual.

## Known-good validation anchors
- Grand totals: Revenue 11,100; Cost 7,800; Margin 3,300; Margin % 29.7297%.
- Q1 2024 Revenue 4,100; Q1 2025 Revenue 7,000; Q1 2025 YoY 70.73%.
- Row counts: DimDate 423, DimCustomer 4, DimProduct 3, DimRegion 2, FactSales 7.
````

Commit it to your `build/contoso-sales` branch. From here on, Copilot applies these rules
automatically — you'll notice the later prompts can be shorter because the repo already carries
the conventions.

```
git add .github/copilot-instructions.md
git commit -m "Add Copilot repository instructions"
git push
```

> As an alternative to one repo-wide file, you can split guidance into
> `.github/instructions/*.instructions.md` files with an `applyTo` glob to scope rules to
> certain paths. One `copilot-instructions.md` is plenty for this solution.

## Verify the agent workspace

Now open **Copilot Chat** in **Agent mode**. Because the solution repo is open and its instructions
file exists, new chats automatically receive the solution conventions. Open the **tools** and
**skills** lists and confirm the three layers are live:

- **Extensions** — the first-party set is installed and enabled: Microsoft Fabric, TMDL,
  MSSQL, GitHub Pull Requests, GitHub Actions, Python/Jupyter, Data Wrangler.
- **MCP servers** — the following appear in the Copilot **tools** list:
  - Microsoft **Fabric MCP** (inspect and change Fabric items),
  - **Power BI Modeling MCP** (author semantic models),
  - **Microsoft Learn MCP** (grounded documentation),
  - **GitHub** tools (issues, pull requests).
- **Skills** — `fabric-skills` and `powerbi-authoring` appear in the available skills.

If a server is missing, start it from **MCP: List Servers** in the Command Palette, or check
that MCP auto-start is configured.

Open the **Fabric explorer** in the Microsoft Fabric extension and confirm you can see the
**Contoso Sales Dev** workspace from [Step 2](02-create-fabric-workspace.md). The extension's tree
lists workspaces and their items, but it does **not** show Git/source-control status — so verify the
Git connection from [Step 3](03-connect-github.md) one of these ways instead:

- **Ask Copilot** (it runs `fab api`):

  ```
  Show the Git connection status for my "Contoso Sales Dev" workspace.
  ```

  Expect `gitConnectionState: ConnectedAndInitialized` pointing at `contoso-sales-fabric`,
  `build/contoso-sales`, and `/src/fabric`.
- **Fabric portal** — open the workspace → **Source control** (or **Workspace settings → Git
  integration**), which shows the connected repo, branch, and folder.

## Why this matters

> A skill supplies the process and domain guidance. An MCP server supplies actions or trusted
> context. A VS Code extension supplies the developer interface. Copilot coordinates these
> layers — but Git remains the system of review and Fabric remains the execution platform.

Next: [Step 5 — Plan the solution with Copilot](05-plan-with-copilot.md).
