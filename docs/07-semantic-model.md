---
title: 7. Build and validate the semantic model
nav_order: 8
---

# Step 7 — Build and validate the semantic model

**Goal:** create a Direct Lake semantic model in Fabric, shape it into a clean star schema with
trusted measures, validate it with DAX, and capture it as reviewable TMDL through Fabric Git
integration.

**What Copilot uses:** the **Fabric web** (create the Direct Lake model), Copilot + the **Power BI
Modeling MCP** (author the model in the workspace), **Fabric Git integration** (capture the TMDL into
`src/fabric/`), and the **TMDL** extension (readable diffs on the pulled source).

## Do it

### Create the Direct Lake semantic model in Fabric

Everything in this solution is a **workspace item** captured into `src/fabric/` the same way —
through **Fabric Git integration**, exactly like the notebook in
[Step 6](06-build-data-path.md#commit-the-notebook-to-git-from-the-workspace). The semantic model is
no exception: you **create it in Fabric, author it there with Copilot, then commit it to Git**. One
copy, one mechanism — no local PBIP, no export, no "two representations."

It's a **Direct Lake** model: it reads the Delta tables straight from OneLake — no import, no data
copy, always current. The model lives in the **Contoso Sales Dev** workspace and you author it in
place; Git mirrors it as reviewable TMDL.

1. **Create the model in the Fabric portal.** In the **Contoso Sales Dev** workspace item list,
   hover **ContosoSalesLH**, select the **… (More options)** menu, and choose **New semantic model**.
   In the dialog, name it **`Contoso Sales`** (with the space — not `ContosoSalesLH`, which is the
   Lakehouse's auto-created default model), confirm the **Contoso Sales Dev** workspace, select the
   five tables (they appear **lowercase** — `factsales`, `dimdate`, `dimcustomer`, `dimproduct`,
   `dimregion` — because Spark registers table names in lowercase), and **Confirm**. It's created in
   **Direct Lake** storage mode and opens for live editing in the browser.

> **Table names come in lowercase.** The Lakehouse tables are `factsales`/`dimdate`/… (Spark
> lowercases them). DAX is case-insensitive, so measures work either way — but for a clean model
> you'll **rename the model tables** to `FactSales`, `DimDate`, `DimCustomer`, `DimProduct`,
> `DimRegion` in the apply step below. Column names already keep their case (`OrderId`, `DateKey`, …).

> **Direct Lake modeling notes.** Calculated *columns* and most calculated *tables* aren't supported
> on Direct Lake tables — which is fine here, because this solution prefers **measures** and builds
> `DimDate` as a real Delta table in the notebook (Step 6), not a DAX calculated table. Marking the
> date table, sorting `MonthName` by `MonthNumber`, hiding keys, and all the measures below are
> fully supported. Later steps ([Step 11](11-orchestrate.md), [Step 12](12-consume.md)) refer to the
> model as `Contoso Sales`, so use that exact name.

You author this model in place and capture it with Git integration. The **TMDL** extension gives you
readable diffs on the model files once you pull them, and the **Power BI Modeling MCP** does the
authoring below.

### How a model change flows

Every change in this step follows the same loop:

1. The model **lives in the workspace** (Direct Lake). Copilot authors it through the **Power BI
   Modeling MCP** connected to that **workspace** model — Fabric semantic models expose an XMLA
   endpoint that modeling tools connect to. *If your Modeling MCP build can't reach a remote
   workspace model, open the model in the browser with **Open data model** (or **Edit in Desktop**)
   and make the same edits there.*
2. **Copilot drives the MCP** to make the change (a measure, a relationship, the date table) in a
   **transaction** so it applies atomically. Changes are **live in the workspace model** immediately
   — there's no separate save.
3. **Validate with DAX** (the MCP runs queries) against the known-good totals.
4. **Capture into Git** exactly like the notebook: commit the workspace → `git pull` → review the
   TMDL diff.
5. PR in [Step 9](09-review-in-github.md) → deploy via fabric-cicd in [Step 10](10-deploy.md).

### Inspect first

Connect the Modeling MCP to the **`Contoso Sales`** model in the **Contoso Sales Dev** workspace and
take stock before changing anything:

```
Using the Power BI Modeling MCP and the powerbi-authoring skill, connect to
the "Contoso Sales" semantic model in the "Contoso Sales Dev" workspace.
Inspect and report: every table and its columns with data types;
all relationships and their cardinality and filter direction; whether a date
table is marked and on which column; and every existing measure. Compare the
model against Power BI star-schema best practices and this repo's conventions
(FactSales + DimDate/DimCustomer/DimProduct/DimRegion, single-direction
one-to-many relationships, measures over calculated columns). List gaps and
proposed changes. Report findings only — do not make any changes yet.
```

### Apply the model changes

Paste this single prompt — it contains every relationship, setting, and measure (with exact DAX and
format strings) needed:

```
Using the Power BI Modeling MCP, apply all of the following semantic-model
changes to the "Contoso Sales" model in the "Contoso Sales Dev" workspace, in a
single transaction. First, rename the model tables from their lowercase source
names to exactly FactSales, DimDate, DimCustomer, DimProduct, DimRegion (the
Lakehouse tables are lowercase; these are the model display names). Do not
rename them to business-friendly names. Prefer measures over calculated columns;
do not add a calculated column when a measure works.

Relationships (single-direction, one-to-many, from the dimension key to the fact
key; do not relate dimensions to each other):
- DimDate[DateKey] 1-* FactSales[DateKey]
- DimCustomer[CustomerId] 1-* FactSales[CustomerId]
- DimProduct[ProductId] 1-* FactSales[ProductId]
- DimRegion[RegionId] 1-* FactSales[RegionId]

Model settings:
- Mark DimDate as the date table using DimDate[Date].
- Sort DimDate[MonthName] by DimDate[MonthNumber].
- Hide every technical key column (all *Id and *Key columns, including DateKey)
  from report view. Keep DimDate[Date] visible (time intelligence uses it).
- Disable auto date/time for this model (a real DimDate date table replaces it).

Measures — create each with the exact DAX and format string, in a "Sales"
display folder, and give each a clear description:

1. Revenue
   DAX: SUMX ( FactSales, FactSales[Quantity] * FactSales[UnitPrice] )
   Format: $#,0.00;($#,0.00);-

2. Cost
   DAX: SUMX ( FactSales, FactSales[Quantity] * FactSales[UnitCost] )
   Format: $#,0.00;($#,0.00);-

3. Margin
   DAX: [Revenue] - [Cost]
   Format: $#,0.00;($#,0.00);-

4. Margin %
   DAX: DIVIDE ( [Margin], [Revenue] )
   Format: 0.00%;-0.00%;-

5. Revenue YTD
   DAX: TOTALYTD ( [Revenue], DimDate[Date] )
   Format: $#,0.00;($#,0.00);-

6. Revenue Prior Year
   DAX: CALCULATE ( [Revenue], SAMEPERIODLASTYEAR ( DimDate[Date] ) )
   Format: $#,0.00;($#,0.00);-

7. Revenue YoY %
   DAX: DIVIDE ( [Revenue] - [Revenue Prior Year], [Revenue Prior Year] )
   Format: 0.00%;-0.00%;-

Use DIVIDE() for every ratio (never "/"). Show the planned changes, apply them
in one transaction, then report what changed so I can review the TMDL diff.
```

These changes apply **live to the workspace model** — there's no local save step. You'll capture
them into Git after validating (see **Capture the model into Git** below), then review the TMDL diff
once you pull.

> **Expected on Direct Lake:** right after adding relationships, time-intelligence measures may
> report *"relationship needs to be recalculated."* That's normal — a **Full refresh** of the model
> reframes it and the measures evaluate. Ask Copilot to trigger the refresh, or use **Refresh** in
> the workspace, then re-run the validation below.

### Validate the measures

```
Using the Power BI Modeling MCP, run DAX queries to validate every new
measure against the known-good anchors, and return the query results as
evidence:
- Grand totals: Revenue 11,100; Cost 7,800; Margin 3,300; Margin % 29.7297%.
- Q1 2025 by region: East Revenue 4,800 / Margin 1,300; West Revenue 2,200 /
  Margin 800.
- Q1 year over year: Revenue 7,000; Revenue Prior Year 4,100; Revenue YoY %
  70.73%.
- Revenue YTD accumulates within a year and resets at year start.
- Margin % uses DIVIDE and returns blank (not an error) when Revenue is 0.

Show each query and its result next to the expected value, mark pass/fail per
measure, and flag anything that does not match. Do not change measures unless I
approve a fix.
```

### Capture the model into Git

The model now exists and is validated **in the workspace**, showing as *uncommitted* in the Fabric
Source control panel. Capture it into `src/fabric/` the same way you captured the notebook in
[Step 6](06-build-data-path.md#commit-the-notebook-to-git-from-the-workspace) — via **Fabric Git
integration**, not a local export:

- **Ask Copilot** (it runs `fab api`):

  ```
  Commit the pending changes in the "Contoso Sales Dev" workspace to its
  connected Git branch: call git status to list what's uncommitted and read the
  workspaceHead, then commit all changes with mode All and a message like "Add
  Contoso Sales semantic model". Confirm the workspace reports no pending
  changes afterward.
  ```

  (Under the hood: `git/status` → `git/commitToGit` with `mode: All`.) Or use the workspace
  **Source control** panel in the portal.
- Then pull it into your clone:

  ```
  git switch build/contoso-sales
  git pull
  ```

The model lands under `src/fabric/` as a **`Contoso Sales.SemanticModel/` folder** — `definition.pbism`
plus a `definition/` folder of **TMDL** files and a `.platform` metadata file. Open the TMDL in VS
Code (the **TMDL** extension gives syntax highlighting and readable diffs) to see your measures,
relationships, and metadata as source. This is the reviewable definition that flows through the PR in
[Step 9](09-review-in-github.md) and deploys via fabric-cicd in [Step 10](10-deploy.md).

> **Confirm the sync in the Fabric UI.** Open the **Contoso Sales Dev** workspace in the browser and
> click the **Source control** icon (top-right). Because Git integration is **two-way**, the panel
> should now show **no pending changes** — the badge is back to **0** and the **Contoso Sales**
> semantic model appears committed at the same `build/contoso-sales` commit you just pulled locally.
> The workspace and the branch are in lockstep.

## Verify

**How to run these DAX queries.** The Copilot-first way is the **Power BI Modeling MCP** — ask
Copilot to run each `EVALUATE` query against the **Contoso Sales** workspace model (that's what the
**Validate the measures** prompt above does), and it returns the result table. To run them by hand,
use the **DAX query view** in the Fabric web (open the model → **Open data model** → **DAX query
view**) or in Power BI Desktop. The **MSSQL** extension runs **T-SQL** against the SQL endpoint, not
DAX — but it cross-checks the same grand totals ([Step 6](06-build-data-path.md)); there's no
separate "run DAX" VS Code extension in this toolset.

**Grand totals:**

```
EVALUATE
ROW (
    "Revenue", [Revenue],
    "Cost", [Cost],
    "Margin", [Margin],
    "Margin %", [Margin %]
)
```
Expected:
```
Revenue = 11100
Cost = 7800
Margin = 3300
Margin % = 0.297297...
```

**Q1 2025 by region:**

```
EVALUATE
CALCULATETABLE (
    SUMMARIZECOLUMNS (
        DimRegion[RegionName],
        "Revenue", [Revenue],
        "Margin", [Margin],
        "Margin %", [Margin %]
    ),
    TREATAS ( { 2025 }, DimDate[Year] ),
    TREATAS ( { "Q1" }, DimDate[Quarter] )
)
ORDER BY
    [Revenue] DESC
```
Expected:
```
East | 4800 | 1300 | 27.0833%
West | 2200 |  800 | 36.3636%
```

**Year over year:**

```
EVALUATE
CALCULATETABLE (
    ROW (
        "Revenue", [Revenue],
        "Revenue Prior Year", [Revenue Prior Year],
        "Revenue YoY %", [Revenue YoY %]
    ),
    TREATAS ( { 2025 }, DimDate[Year] ),
    TREATAS ( { "Q1" }, DimDate[Quarter] )
)
```
Expected:
```
Revenue = 7000
Revenue Prior Year = 4100
Revenue YoY % = 0.707317...
```

Finally, review the **TMDL diff** on the pulled `Contoso Sales.SemanticModel/` — the model change is
readable source, line by line — and confirm the folder is present under `src/fabric/`.

## Optional — a teachable failure

Replace `DIVIDE` in `Margin %` with direct division (`[Margin] / [Revenue]`). Ask Copilot why
`DIVIDE` is safer (it handles divide-by-zero and blanks), restore the measure, and rerun the
grand-total query. This shows the validate loop catching a real correctness issue.

Next: [Step 8 — Author and verify the report](08-author-report.md).
