# Fabric + Power BI with GitHub Copilot

Build a complete Microsoft Fabric and Power BI solution — from an empty workspace to a
deployed, queryable analytics product — using **GitHub Copilot** in VS Code as the driver.

This repository is a hands-on tutorial. It shows how Fabric and Power BI artifacts can
participate in the same AI-assisted engineering lifecycle as application code: **plan,
build, validate, review, deploy, and operate** — with GitHub as the system of record.

## What it demonstrates

Three layers work together, and the tutorial calls out which one is doing the work at every step:

| Layer | Purpose | Examples used here |
| --- | --- | --- |
| **Agent skills** | Tell Copilot *how* to perform a specialized task | `fabric-skills` (data path), `powerbi-authoring` (report planning/design/PBIR) |
| **MCP servers** | Give Copilot *tools* to inspect and change external systems | Fabric MCP, Power BI Modeling MCP, Data Factory MCP (preview), Microsoft Learn MCP, GitHub |
| **CLIs** | Give Copilot *commands* the skills and steps drive | `fab` (workspace/capacity, OneLake, Git integration), `powerbi-report-author` + `powerbi-desktop` (PBIR + Desktop Bridge), `gh`/`az` |
| **VS Code extensions** | Provide the interactive *developer experience* | Microsoft Fabric, TMDL, MSSQL, GitHub Pull Requests, GitHub Actions |

Alongside the AI layers, development happens in a **GitHub-connected Fabric workspace**, with
explicit Git commit/update operations. Reviewed changes flow through pull requests and checks
before CI/CD publishes them to a **separate Test workspace**.

### How Copilot knows which tools to use

Copilot only knows about the `fab` CLI, the MCP servers, and this project's conventions because
this repo ships a **[`.github/copilot-instructions.md`](.github/copilot-instructions.md)**. GitHub
Copilot loads it automatically — in both VS Code Copilot Chat and the `copilot` CLI — whenever you
work in the folder. It routes each task to the right tool (for example, **workspace and capacity
operations use the `fab` CLI**, not an MCP, because the Fabric MCP only creates items *inside* an
existing workspace).

> Keep the tutorial folder open when you prompt Copilot. Start it in an unrelated empty folder and
> the instructions don't load — the agent won't know `fab` exists and will say it can't create a
> workspace. The solution repo you create later gets its own instructions file as the first action
> in [Step 4](docs/04-clone-and-open.md), before you ask Copilot to build the solution.

## The scenario

Contoso needs a regional sales-performance solution. Over the tutorial you will:

1. Ingest a small sales CSV into OneLake.
2. Transform it into a star schema (`FactSales`, `DimDate`, `DimCustomer`, `DimProduct`, `DimRegion`) with a Spark notebook.
3. Build a **Direct Lake** semantic model in the workspace with trusted measures (Revenue, Cost, Margin, Margin %, Revenue YTD, Revenue Prior Year, Revenue YoY %), authored via the Power BI Modeling MCP.
4. Author an executive Power BI report as local PBIR with the `powerbi-authoring` skill, verified in Power BI Desktop via the Desktop Bridge.
5. Review the change through a GitHub pull request.
6. Deploy reviewed source to a separate Test workspace through Fabric CI/CD (fabric-cicd).
7. Orchestrate a scheduled refresh with Data Factory, then query the finished product.

The dataset is deliberately tiny so every total is easy to verify by hand. Every workspace item —
Lakehouse, notebook, and semantic model — is captured into the solution repo's `src/fabric/` via
**Fabric Git integration**; the report is authored locally and committed with plain `git`. Both flow
through the same pull request and deploy to **Contoso Sales Test**. Step 10 introduces a different
Test CSV fixture, so you can prove the deployed solution reads Test's data rather than Dev's.

## Quick start

1. **Prerequisites** — Windows with [PowerShell 7+](https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-windows),
   [Git](https://git-scm.com/download/win), and the [App Installer](https://apps.microsoft.com/detail/9nblggh4nns1) (provides `winget`).
   You also need a GitHub Copilot license and access to a Microsoft Fabric capacity.
   [Power BI Desktop](https://www.microsoft.com/download/details.aspx?id=58494) is required for
   [Step 8](docs/08-author-report.md) (the Desktop Bridge renders and screenshots the report);
   enable its **Preview features → "Enable external tool access… through secure local APIs"** toggle.
2. **Run setup** from the repository root:

   ```
   pwsh -File scripts/setup.ps1
   ```

   This is a one-time workstation setup: it installs the CLIs, the Fabric CLI (`fab`, globally via
   pipx), the Fabric Copilot skills, and the Power BI report-authoring CLIs (`powerbi-report-author`,
   `powerbi-desktop`), so the tools work in every repo you open. See
   [the environment setup guide](docs/01-environment-setup.md) for details.
3. **Follow the tutorial** in [`docs/`](docs/index.md), starting at step 1.

## The tutorial

The full step-by-step walkthrough lives in [`docs/`](docs/index.md):

1. [Set up your environment](docs/01-environment-setup.md)
2. [Create a Fabric workspace](docs/02-create-fabric-workspace.md)
3. [Connect the workspace to GitHub](docs/03-connect-github.md)
4. [Open the solution and add Copilot instructions](docs/04-clone-and-open.md)
5. [Plan the solution with Copilot](docs/05-plan-with-copilot.md)
6. [Build the Fabric data path](docs/06-build-data-path.md)
7. [Build and validate the semantic model](docs/07-semantic-model.md)
8. [Author and verify the report](docs/08-author-report.md)
9. [Review through GitHub](docs/09-review-in-github.md)
10. [Deploy through Fabric CI/CD](docs/10-deploy.md)
11. [Orchestrate the Test refresh](docs/11-orchestrate.md)
12. [Consume the solution](docs/12-consume.md)

Reference material (sample data, expected totals, recovery tips, links) is in
[the appendix](docs/reference.md).

### Publishing the tutorial as a website

The `docs/` folder is configured for [GitHub Pages](https://docs.github.com/pages) with the
[Just the Docs](https://just-the-docs.com/) theme. To publish it: push this repo to GitHub,
then in **Settings → Pages** set the source to **Deploy from a branch**, branch **main**,
folder **/docs**. GitHub builds and serves the tutorial with sidebar navigation and search.

## Repository layout

```
.
├── README.md                     # This overview
├── .github/
│   └── copilot-instructions.md   # Tells Copilot which tools exist and when to use them
├── docs/                         # Step-by-step tutorial (GitHub Pages)
│   ├── _config.yml
│   ├── index.md
│   ├── 01-environment-setup.md
│   ├── … 02–12 …
│   └── reference.md
├── scripts/
│   ├── setup.ps1                 # One-shot local environment setup (Windows)
│   └── requirements.txt          # Pinned Python deps (fabric-cicd, ms-fabric-cli)
└── .vscode/
    ├── extensions.json           # Recommended first-party extensions
    └── settings.json
```

## Two repositories

This project uses **two** repositories, and the tutorial keeps them separate on purpose:

- **This repo (the tutorial)** — the `docs/` walkthrough and `scripts/setup.ps1`. You clone it
  to read the tutorial and set up your machine.
- **The solution repo** — a **new, empty** repo you create in
  [Step 3](docs/03-connect-github.md). Your blank Fabric workspace connects to it with Git
  integration, and the Fabric item definitions (`src/fabric/`), tests, and CI land there as you
  build. It starts empty — that's the point.

Nothing from the tutorial is pushed into the solution repo.

## First-party tools only

Every extension and skill used here is Microsoft- or GitHub-owned. Nothing depends on a
community extension. The recommended set is in [`.vscode/extensions.json`](.vscode/extensions.json).
