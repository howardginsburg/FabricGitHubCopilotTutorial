---
title: Reference
nav_order: 14
---

# Reference appendix

Supporting material for the tutorial: expected results, the first-party tool set, a recovery
matrix, and links.

## Expected totals

### Dev fixture (Steps 6–9)

The sample dataset is seven rows. Every total is verifiable by hand.

| Period | Revenue | Cost | Margin | Margin % |
| --- | ---: | ---: | ---: | ---: |
| Q1 2024 | 4,100 | 2,900 | 1,200 | 29.27% |
| Q1 2025 | 7,000 | 4,900 | 2,100 | 30.00% |
| Q1 2025 YoY | 70.73% | 68.97% | 75.00% | +0.73 pp |

Grand totals across the dataset: Revenue = 11,100; Cost = 7,800; Margin = 3,300;
Margin % = 29.7297%.

Q1 2025 by region: East = 4,800 revenue / 1,300 margin / 27.0833%;
West = 2,200 revenue / 800 margin / 36.3636%.

Row counts after transformation: `DimDate` 423, `DimCustomer` 4, `DimProduct` 3,
`DimRegion` 2, `FactSales` 7. The date range covers 2024-01-15 through 2025-03-12 inclusive.

### Test fixture (Step 10 onward)

[Step 10](10-deploy.md) introduces `data/raw/sales-test.csv`: the same records, dates, keys,
prices, and costs, with **every Quantity doubled**. The original Dev fixture and all the
expectations above remain unchanged.

| Period | Revenue | Cost | Margin | Margin % |
| --- | ---: | ---: | ---: | ---: |
| Q1 2024 | 8,200 | 5,800 | 2,400 | 29.27% |
| Q1 2025 | 14,000 | 9,800 | 4,200 | 30.00% |
| Q1 2025 YoY | 70.73% | 68.97% | 75.00% | +0.73 pp |

Grand totals in **Test**: Revenue = **22,200**; Cost = **15,600**; Margin = **6,600**;
Margin % = 29.7297%.

Q1 2025 by region: East = **9,600** revenue / **2,600** margin / 27.0833%;
West = **4,400** revenue / **1,600** margin / 36.3636%.

Row counts remain `DimDate` **423**, `DimCustomer` **4**, `DimProduct` **3**, `DimRegion` **2**,
`FactSales` **7**, covering the same date range with zero missing dimension keys.

Validate both **bindings and monetary totals**: percentages and counts are deliberately identical
and cannot detect a report accidentally reading Dev. Test's notebook, model, report, and pipeline
must reference Test items; Dev must still return the original values above.

## First-party tool set

Only Microsoft- and GitHub-owned extensions and skills are used.

**Required**

- GitHub Copilot and Copilot Chat
- Microsoft Fabric
- Microsoft Fabric MCP Server
- Power BI Modeling MCP Server
- TMDL
- MSSQL
- GitHub Pull Requests and Issues
- GitHub Actions
- Skills for Fabric Copilot plugin (`fabric-skills`)
- Power BI authoring Copilot plugin (`powerbi-authoring`)

**Scenario-dependent**

- SQL Database Projects — Fabric SQL schema-as-code.
- Python and Jupyter — editing notebook code locally.
- Data Wrangler — visual profiling and generated Pandas code.
- Power BI Desktop Bridge — live report reload and screenshot review (`powerbi-desktop` CLI).
- Remote Power BI MCP — natural-language questions against a published model.
- Data Factory MCP (preview) — orchestrating and scheduling refresh pipelines. Requires the
  .NET 10 SDK and a `.vscode/mcp.json` registration in the solution repo (see
  [Step 11](11-orchestrate.md)).

## Evidence checklist

Capture these so every claim has proof:

| Claim | Evidence |
| --- | --- |
| Copilot is grounded in current docs | Microsoft Learn MCP citation in the planning response |
| Fabric tools operate on the intended workspace | Workspace name and read-only inventory before changes |
| Transformation is correct | Row counts, SQL totals, and zero missing dimension keys |
| Measures are correct | DAX query output matching expected values |
| The model is source controlled | TMDL diff |
| The report is structurally valid | PBIR validation output |
| The report is visually usable | Before-and-after Desktop screenshots |
| Review controls are active | Pull request approval and GitHub Actions checks |
| Deployment uses approved source | Workflow commit SHA and target item inventory |
| Test is isolated from Dev | Distinct workspace/item IDs, Test bindings, and Test Revenue 22,200 versus unchanged Dev Revenue 11,100 |
| Deployment identity is authorized | Exact main-bound OIDC trust, confirmed tenant policy, Test Contributor grant, and successful Fabric preflight |
| Refresh is orchestrated and scheduled | Data Factory pipeline run status and enabled schedule |
| The final answer is grounded | Remote Power BI MCP response citing period and measures |

## Recovery matrix

| Failure | Recovery |
| --- | --- |
| MCP server does not start | Restart it from **MCP: List Servers**, then use a prepared artifact if it stays unavailable |
| Authentication expires | Reauthenticate once; don't troubleshoot identity live |
| Fabric capacity is unavailable | Use saved run results and preloaded tables |
| OneLake upload fails | Continue with files already staged in the Lakehouse |
| Notebook/pipeline run is slow | Show the submitted run, then switch to saved output |
| Modeling MCP cannot connect | Open the prepared TMDL diff and saved DAX validation |
| Power BI Desktop reload fails | Use prepared before-and-after screenshots |
| GitHub Actions is queued | Open the previous successful run |
| Fabric deployment is slow | Show prior deployment history and verify existing target items |

## Out of scope

Kept for follow-up material: Fabric User Data Functions, custom Power Query connectors,
Real-Time Intelligence and Eventhouse, Terraform provisioning, cross-cloud migration, and
community VS Code extensions.

## Links

- [Power BI Agentic overview](https://learn.microsoft.com/power-bi/developer/agentic/power-bi-agentic-overview)
- [Power BI MCP servers](https://learn.microsoft.com/power-bi/developer/mcp/mcp-servers-overview)
- [Power BI Report Authoring skill](https://learn.microsoft.com/power-bi/developer/agentic/power-bi-report-authoring-skill-overview)
- [Power BI Desktop projects](https://learn.microsoft.com/power-bi/developer/projects/projects-overview)
- [Microsoft Fabric extensions for VS Code](https://learn.microsoft.com/fabric/data-engineering/set-up-fabric-vs-code-extension)
- [Microsoft Fabric CI/CD](https://learn.microsoft.com/fabric/cicd/cicd-overview)
- [Microsoft Fabric CLI](https://learn.microsoft.com/rest/api/fabric/articles/fabric-command-line-interface)
- [fabric-cicd](https://microsoft.github.io/fabric-cicd/)
- [fabric-cicd parameterization](https://microsoft.github.io/fabric-cicd/1.3.0/how_to/parameterization/)
- [Fabric service-principal tenant settings](https://learn.microsoft.com/fabric/admin/service-admin-portal-developer)
- [GitHub OIDC subjects](https://docs.github.com/en/actions/reference/security/oidc#example-subject-claims)
- [Data Factory MCP (preview)](https://github.com/microsoft/DataFactory.MCP)
- [Skills for Fabric](https://github.com/microsoft/skills-for-fabric)
- [GitHub Copilot CLI](https://docs.github.com/copilot/how-tos/set-up/install-copilot-cli)
