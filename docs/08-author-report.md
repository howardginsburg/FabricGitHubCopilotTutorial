---
title: 8. Author and verify the report
nav_order: 9
---

# Step 8 — Author and verify the report

**Goal:** author a focused, accessible executive report page as **local PBIR** with the
`powerbi-authoring` skill, validate it with the `powerbi-report-author` CLI, and verify the rendered
page in **Power BI Desktop** through the **Desktop Bridge** — an edit → validate → reload → screenshot
loop.

**What Copilot uses:** the **`powerbi-authoring`** skill (report planning, design, PBIR authoring),
the **`powerbi-report-author`** CLI (edit + validate PBIR), and the **`powerbi-desktop`** Desktop
Bridge CLI (open, reload, screenshot Power BI Desktop). All three are installed by
[`scripts/setup.ps1`](01-environment-setup.md) in [Step 1](01-environment-setup.md).

> **Prerequisites (from [Step 1](01-environment-setup.md)).** Confirm the CLIs are on PATH —
> `powerbi-report-author --version` and `powerbi-desktop --version` — and that **Power BI Desktop**
> has **File → Options and settings → Options → Preview features → "Enable external tool access to
> Power BI Desktop through secure local APIs"** enabled (restart Desktop after enabling). If the
> CLIs are missing, re-run `pwsh -File scripts/setup.ps1`.

## Where the report comes from

Unlike the semantic model (created and authored in the workspace, [Step 7](07-semantic-model.md)),
the report is authored **locally**: the `powerbi-authoring` skill scaffolds and edits a **PBIR**
report project on disk under `src/fabric/`, bound to the **`Contoso Sales`** Direct Lake model in the
workspace by connection (the model stays remote — no local copy of it). The local
**`Contoso Sales.Report/`** PBIR is the source of truth; you commit it with **plain `git`**, it flows
through the PR in [Step 9](09-review-in-github.md), and fabric-cicd publishes it to **Test** in
[Step 10](10-deploy.md).

> **Two capture mechanisms, by tool.** The model is a workspace item captured via **Git integration**
> (commit → pull); the report is authored locally by the skill and captured with **plain `git`**.
> Both land in `src/fabric/` and go through the same pull request.

## Do it

### Plan the page

```
Using the powerbi-authoring skill's report planning and design guidance, plan
the first page of an executive sales report on the "Contoso Sales" semantic
model for regional managers.

The page must answer:
- Are revenue and margin on target?
- Which regions and products explain the result?
- How is performance changing over time?

Constraints:
- Use only existing model measures (Revenue, Margin, Margin %, Revenue YoY %,
  etc.) — never create implicit measures or duplicate model logic in a visual.
- Single 16:9 page: a title, a four-card KPI row, a monthly Revenue+Margin
  trend, a Revenue-by-Region comparison, a Revenue-by-Product breakdown, a
  region/product detail matrix, and Year/Quarter/Region/Category slicers.
- Keep it focused and accessible (clear titles, alt text, contrast not reliant
  on color alone).

Propose the concrete layout, the visual type and exact fields/measures for
each visual, and the cross-filter interactions — before editing any PBIR.
```

The target page — a 16:9 canvas, one page:

| Area | Visual | Fields/measures | Purpose |
| --- | --- | --- | --- |
| Header | Text box | Report title and selected period | Establish context |
| KPI row | Four cards | Revenue, Margin, Margin %, Revenue YoY % | Performance at a glance |
| Left center | Line and clustered column | Axis: YearMonth; columns: Revenue; line: Margin | Trend and economics |
| Right center | Bar chart | Axis: RegionName; value: Revenue; tooltip: Margin, Margin % | Geographic contribution |
| Lower left | Bar chart | Axis: ProductName; value: Revenue; legend: Category | Product contribution |
| Lower right | Matrix | RegionName, ProductName; Revenue, Margin, Margin % | Detail |
| Filter strip | Slicers | Year, Quarter, RegionName, Category | Focused exploration |

```
+------------------------------------------------------------------+
| Executive Sales Overview                         [Year] [Quarter] |
+---------------+---------------+---------------+------------------+
| Revenue       | Margin        | Margin %      | Revenue YoY %    |
+---------------+---------------+---------------+------------------+
|                               |                                  |
| Revenue and Margin by Month   | Revenue by Region                |
|                               |                                  |
+-------------------------------+----------------------------------+
|                               |                                  |
| Revenue by Product            | Region and Product Detail        |
|                               |                                  |
+-------------------------------+----------------------------------+
```

### Scaffold and author the report in PBIR

Ask Copilot to scaffold the report project and implement the approved page. The `powerbi-authoring`
skill writes PBIR files under `src/fabric/` and validates them with `powerbi-report-author`:

```
Using the powerbi-authoring skill, scaffold a Power BI report project named
"Contoso Sales" under src/fabric/, bound by connection to the "Contoso Sales"
semantic model in the "Contoso Sales Dev" workspace (Direct Lake — keep the
model remote, don't create a local semantic model). Then implement the approved
first page:
- a header text box with the report title,
- a KPI row of four cards: Revenue, Margin, Margin %, Revenue YoY %,
- a line-and-clustered-column visual (axis YearMonth; columns Revenue; line
  Margin),
- a bar chart of Revenue by RegionName (tooltip Margin, Margin %),
- a bar chart of Revenue by ProductName (legend Category),
- a matrix of RegionName/ProductName with Revenue, Margin, Margin %,
- slicers for Year, Quarter, RegionName, Category.

Apply consistent theme, alignment, spacing, titles, alternative text, and
number formatting (currency and percent come from the model measures). Use only
explicit model measures — never implicit aggregations or duplicated model logic.
Run `powerbi-report-author validate` on the .Report folder after each batch of
changes and fix any errors before continuing.
```

This produces `src/fabric/Contoso Sales.Report/` (PBIR) and a `Contoso Sales.pbip` manifest — the
files you'll open in Desktop next.

### Verify in Power BI Desktop (Desktop Bridge)

The skill verifies the *rendered* page by opening the project in Power BI Desktop and driving it
through the Desktop Bridge. Ask Copilot to run the loop:

```
Using the powerbi-desktop Desktop Bridge CLI, open src/fabric/Contoso Sales.pbip
in Power BI Desktop, reload it, and capture a screenshot of the page. Review the
rendered screenshot against the acceptance criteria and list issues ranked by
impact. Make only the highest-value fix in PBIR, re-validate, reload, and
screenshot again so I can compare.
```

> **"Set up the remote model for your PBIP" dialog.** The first time Power BI Desktop opens the
> project, it asks how to bind the Direct Lake model (it can't run locally). In the dialog:
> 1. **Workspace** → select **Contoso Sales Dev** (this enables the options below).
> 2. Choose **Use existing semantic model** (not *Create new*).
> 3. Pick **Contoso Sales**, then **Done**.
>
> This binds the report to the existing workspace model by connection. The choice is remembered, so
> later opens won't prompt. (Also enable the external-tool preview feature — see the prerequisites
> above — or the Bridge can't reload/screenshot.)

> **Visuals blank or "needs to be recalculated"? Reframe the model.** Direct Lake tables must be
> *reframed* before they return data — the first render (or a render right after the Step 7
> relationship/measure changes) can come up empty. Trigger a **Full refresh** of the `Contoso Sales`
> model, then reload the report:
> - **Ask Copilot:** `Refresh the "Contoso Sales" semantic model in the "Contoso Sales Dev"
>   workspace (full refresh) so its Direct Lake tables reframe, then reload the report in Power BI
>   Desktop and capture a new screenshot.`
> - **Or by hand:** in the workspace, select **… → Refresh** on the `Contoso Sales` model (or
>   **Refresh now** from the model's page), wait for it to finish, then re-run the reload/screenshot.
>
> This is the same Direct Lake reframe noted in [Step 7](07-semantic-model.md) — once reframed, the
> visuals populate and stay current.

### Capture into Git

The report is local PBIR, so commit it with **plain `git`** (not Fabric Git integration):

```
git add "src/fabric/Contoso Sales.Report" "src/fabric/Contoso Sales.pbip"
git commit -m "Add executive sales report"
git push
```

It's now reviewable PBIR that flows through the pull request in [Step 9](09-review-in-github.md) and
deploys to the separate Test workspace via fabric-cicd in [Step 10](10-deploy.md).

> **Getting the report into Dev is a separate Git update.** A plain `git push` does not create a
> live workspace item automatically, but valid, supported report definitions in the connected
> `src/fabric` folder can appear under **Source control → Updates**. Inspect the incoming changes
> and resolve any conflicts before **Update all** to bring them into Dev. Missing updates are a
> reason to check the connected branch/folder and the report's definition/`.platform` files, not
> evidence that plain-Git commits cannot be imported. The reviewed release into **Test** is
> separate, in [Step 10](10-deploy.md).

## Verify — visual acceptance criteria

- No visual overlaps or clipped titles.
- KPI cards use identical dimensions and spacing.
- Currency and percentage formatting comes from model measures.
- Every chart has a descriptive title.
- Color is not the only way positive and negative performance is communicated.
- Slicers have visible labels and logical defaults.
- Decorative elements do not receive unnecessary tab stops.
- Visuals use explicit model measures, never implicit aggregations.
- The page answers the three business questions without drill-through.

## What to notice

- The **`powerbi-authoring`** skill supplies Power BI-specific planning, design, and PBIR mechanics.
- The report is **authored locally as PBIR** and verified in **Power BI Desktop** via the Desktop
  Bridge — the edit → validate → reload → screenshot loop keeps visual quality honest before the PR.
- **PBIR on disk is the source of truth**; it's committed with plain `git` and deployed to Test
  by fabric-cicd, so the report follows the same review discipline as app code.

Next: [Step 9 — Review through GitHub](09-review-in-github.md).
