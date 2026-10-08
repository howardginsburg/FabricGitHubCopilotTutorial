---
title: Home
nav_order: 1
---

# Fabric + Power BI with GitHub Copilot

Build a complete Microsoft Fabric and Power BI solution — from an empty workspace to a
deployed, queryable analytics product — using **GitHub Copilot** in VS Code as the driver.

This tutorial follows one change from requirement to a deployed Test release and shows where **agent
skills**, **MCP servers**, and **VS Code extensions** each contribute, with **GitHub** as
the system of review and CI/CD.

## What you will build

Contoso needs a regional sales-performance solution. You will:

1. Ingest a small sales CSV into OneLake.
2. Transform it into a star schema.
3. Build a semantic model with trusted measures.
4. Author an executive Power BI report.
5. Review the change through a GitHub pull request.
6. Deploy reviewed source to a separate Test workspace through Fabric CI/CD.
7. Orchestrate a scheduled Test refresh with Data Factory.
8. Query the finished product.

The dataset is deliberately tiny, so every total is easy to verify by hand (see the
[reference appendix](reference.md)). Steps 1–9 build and review the Dev solution; Step 10
adds Test and a different CSV fixture without rebuilding the earlier artifacts.

## The three layers

At each step, this tutorial names which layer is doing the work:

| Layer | Purpose | Examples |
| --- | --- | --- |
| **Agent skills** | Tell Copilot *how* to perform a task | `fabric-skills`, `powerbi-authoring` |
| **MCP servers** | Give Copilot *tools* against live systems | Fabric MCP, Power BI Modeling MCP, Data Factory MCP (preview), Microsoft Learn MCP, GitHub |
| **VS Code extensions** | Provide the developer *experience* | Microsoft Fabric, TMDL, MSSQL, GitHub Pull Requests, GitHub Actions |

## How each step is structured

Every step page uses the same shape:

- **Goal** — what this step accomplishes.
- **What Copilot uses** — the MCP server, CLI, skill, or VS Code extension the agent reaches for,
  and why.
- **Ask Copilot** — the prompt you give it in Agent mode.
- **What Copilot does** — the tools it invokes and commands it runs on your behalf, shown so you can
  follow and approve them.
- **Verify** — how to confirm it worked before moving on.

You drive every step by asking **Copilot** in Agent mode — there are no manual alternatives to pick
between. For each task Copilot chooses the right tool — an **MCP server** (Fabric, Power BI
Modeling, Data Factory, Microsoft Learn), a **CLI** (`fab`, `gh`, `az`), a **skill**, or a **VS Code
extension** — and runs it after you approve. The commands are shown so you can understand and verify
what the agent ran, not so you have to type them yourself.

## Steps

1. [Set up your environment](01-environment-setup.md)
2. [Create a Fabric workspace](02-create-fabric-workspace.md)
3. [Connect the workspace to GitHub](03-connect-github.md)
4. [Open the solution and add Copilot instructions](04-clone-and-open.md)
5. [Plan the solution with Copilot](05-plan-with-copilot.md)
6. [Build the Fabric data path](06-build-data-path.md)
7. [Build and validate the semantic model](07-semantic-model.md)
8. [Author and verify the report](08-author-report.md)
9. [Review through GitHub](09-review-in-github.md)
10. [Deploy through Fabric CI/CD](10-deploy.md)
11. [Orchestrate the Test refresh](11-orchestrate.md)
12. [Consume the solution](12-consume.md)

Then see the [reference appendix](reference.md) for sample data, expected totals, a
recovery matrix, and links.

## Prerequisites at a glance

- Windows with PowerShell 7+, Git, and `winget`.
- A GitHub account and a GitHub Copilot license (Agent mode available).
- Access to a Microsoft Fabric capacity and permission to create workspaces.
- VS Code (or VS Code Insiders).

Start with [Step 1: Set up your environment](01-environment-setup.md).
