---
title: 12. Consume the solution
nav_order: 13
---

# Step 12 — Consume the solution

**Goal:** query the finished product in **Contoso Sales Test** — both as SQL and as a
natural-language question against the published semantic model.

**What Copilot uses:** the Lakehouse **SQL analytics endpoint** (MSSQL extension) and the
**remote Power BI MCP** for governed consumption.

## Do it

### Query with SQL

Ask Copilot to connect **MSSQL** to **Test's** `ContosoSalesLH` SQL analytics endpoint and report
the target workspace/Lakehouse IDs before querying. Reuse the quarterly query from
[Step 6](06-build-data-path.md), but expect the **Test fixture's** totals, not Dev's:

```
SELECT
    d.[Year],
    d.[Quarter],
    CAST(SUM(f.Quantity * f.UnitPrice) AS decimal(18, 2)) AS Revenue,
    CAST(SUM(f.Quantity * (f.UnitPrice - f.UnitCost)) AS decimal(18, 2)) AS Margin
FROM dbo.factsales AS f
INNER JOIN dbo.dimdate AS d ON d.DateKey = f.DateKey
GROUP BY d.[Year], d.[Quarter]
ORDER BY d.[Year], d.[Quarter];
```

> Lakehouse table names are **lowercase and case-sensitive** at the SQL endpoint (`dbo.factsales`,
> `dbo.dimdate`); column names keep their case. See the note in [Step 6](06-build-data-path.md).

Test must return Q1 2024 Revenue **8,200** / Margin **2,400**, and Q1 2025 Revenue **14,000** /
Margin **4,200**. The same query against Dev still returns its original values.

### Ask a natural-language question

Use the **remote Power BI MCP** against the published **Test** model. Select the workspace and
model IDs explicitly; Dev has a model with the same display name:

```
Using the remote Power BI MCP against the published "Contoso Sales" semantic
model in "Contoso Sales Test", first confirm the workspace/model IDs. Then
compare Revenue and Margin by region for the latest complete quarter in
the data. Identify the region with the largest year-over-year Revenue change,
give the figures, and cite the exact measures (e.g. Revenue, Margin,
Revenue YoY %) and the period/filters you applied. Do not recompute the
numbers yourself — read them from the model.
```

## Verify

- The SQL result matches the **Test** quarterly totals (see the
  [reference appendix](reference.md#test-fixture-step-10-onward)).
- The published model answers the business question and **cites the period and measures** it
  used — that citation is your evidence the answer is grounded in the governed model.
- For Q1 2025, Test shows East Revenue **9,600** / Margin **2,600** and West Revenue **4,400** /
  Margin **1,600**. Matching percentages alone are insufficient: those are unchanged from Dev.

## What to notice

- The **remote Power BI MCP** is for governed consumption and insight; the **local Modeling
  MCP** is for authoring. Same platform, two different jobs.
- The answer comes from the reviewed, deployed model — the full loop from requirement to
  grounded insight is closed.

## Recap

You took one requirement from plan to a reviewed Test release:

1. Planned with Copilot, grounded in Microsoft docs.
2. Built the Fabric data path and validated row counts and totals.
3. Authored and validated the semantic model as TMDL source.
4. Authored and visually verified the report in PBIR.
5. Reviewed the change through a GitHub pull request with automated checks.
6. Deployed reviewed source into a separate Test workspace through Fabric CI/CD and secretless OIDC.
7. Orchestrated a scheduled Test refresh with Data Factory.
8. Consumed the result with SQL and natural language.

> Fabric and Power BI artifacts can participate in the same AI-assisted engineering lifecycle
> as application code: **plan, build, validate, review, deploy, and operate** — with Copilot
> coordinating skills, MCP tools, and extensions, and GitHub as the system of record.

See the [reference appendix](reference.md) for expected totals, a recovery matrix, and links.
