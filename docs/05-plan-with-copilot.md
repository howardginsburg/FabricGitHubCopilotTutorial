---
title: 5. Plan the solution with Copilot
nav_order: 6
---

# Step 5 — Plan the solution with Copilot

**Goal:** have Copilot propose the smallest appropriate Fabric architecture, grounded in
current Microsoft documentation, and identify which artifacts belong in source control —
**before** any resource is created.

**What Copilot uses:** Copilot **Agent mode**, the **Microsoft Learn MCP** to ground
platform-specific claims, and the installed **`fabric-skills`** and **`powerbi-authoring`** skills
to shape the plan with the same conventions it will build with in later steps.

## Do it

First, put VS Code Copilot into **Agent mode** so it can call the MCP servers and tools (not just
answer questions):

1. Open the Chat view — **View → Chat**, or `Ctrl+Alt+I`.
2. In the mode dropdown at the top of the Chat view, choose **Agent** (the default is **Ask**).
3. Pick a capable model in the model picker next to it.
4. Confirm your **solution repo** (`contoso-sales-fabric`) is the open folder, so the
   `.github/copilot-instructions.md` you added in [Step 4](04-clone-and-open.md) loads
   automatically.

Then send the planning prompt:

```
We need a regional sales-performance solution in Microsoft Fabric.
It must ingest CSV data into OneLake, produce a star schema, expose a
Power BI semantic model, and deliver an executive report through GitHub
and Fabric CI/CD.

Lean on the fabric-skills and powerbi-authoring skills for Fabric and
Power BI best practices, and ground any platform-specific claims in current
Microsoft Fabric documentation via the Microsoft Learn MCP.

Propose the smallest appropriate Fabric architecture, map each part to the
tool that will build it (Fabric MCP, Power BI Modeling MCP, fab CLI, the
skills), and identify the artifacts that should be source controlled.
Do not create or change resources yet.
```

> **Ask vs. Agent.** In **Ask** mode Copilot only replies with text. **Agent** mode lets it invoke
> the Fabric MCP, Power BI Modeling MCP, Microsoft Learn MCP, and the `fab`/`gh` CLIs — and take
> approved actions. Every remaining step in this tutorial assumes **Agent** mode.

## Expected result

Copilot proposes a compact architecture such as:

- OneLake and a Lakehouse for storage.
- A notebook (or Data Factory pipeline) for transformation.
- Delta tables arranged as a star schema.
- A Power BI semantic model.
- An executive report on that model.
- A GitHub repository with a validation workflow.
- A Fabric deployment pipeline or scripted deployment.

## What to notice

- **Grounding** — the plan cites current Microsoft docs via the Microsoft Learn MCP. That
  citation is your evidence the answer isn't guesswork.
- **Skills shape the plan** — because you pointed Copilot at `fabric-skills` and
  `powerbi-authoring`, the proposed data path and model/report follow the same conventions those
  skills will apply when you build in Steps 6–8. The plan and the build stay consistent.
- **Plan mapped to tools** — each part of the architecture is tied to the tool that will create it
  (Fabric MCP, Power BI Modeling MCP, `fab` CLI), so later steps are execution, not redesign.
- **Plan before write** — Copilot is planning before touching any write-capable tool.
- **Source-controllable artifacts** — the proposed artifacts are readable files (notebook,
  TMDL, PBIR) that Git can review.

Keep this response. The next steps build exactly this approved design.

The star schema you're targeting:

| Table | Key | Attributes |
| --- | --- | --- |
| `FactSales` | — | `OrderId`, `DateKey`, `CustomerId`, `ProductId`, `RegionId`, `Quantity`, `UnitPrice`, `UnitCost` |
| `DimDate` | `DateKey` | Date, year, quarter, month number, month name, year-month |
| `DimCustomer` | `CustomerId` | Customer name |
| `DimProduct` | `ProductId` | Product name, category |
| `DimRegion` | `RegionId` | Region name |

Use single-direction, one-to-many relationships from each dimension key to `FactSales`. Do
not relate dimensions to each other.

Next: [Step 6 — Build the Fabric data path](06-build-data-path.md).
