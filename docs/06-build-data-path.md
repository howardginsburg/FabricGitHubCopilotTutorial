---
title: 6. Build the Fabric data path
nav_order: 7
---

# Step 6 — Build the Fabric data path

**Goal:** create a Lakehouse, upload the sample CSV to OneLake, transform it into the five
star-schema Delta tables, and validate the result.

**What Copilot uses:** Copilot Agent mode + the **Fabric MCP**, the **Microsoft Fabric
extension**, the `fab` CLI, and **MSSQL** for SQL validation.

## The sample data

Save this as `data/raw/sales.csv`. It is deliberately tiny so every total is verifiable by hand.

```
OrderId,OrderDate,CustomerId,CustomerName,ProductId,ProductName,Category,RegionId,RegionName,Quantity,UnitPrice,UnitCost
SO1001,2024-01-15,C001,Alpine Ski House,P100,Pro Laptop,Devices,R01,East,2,1200.00,900.00
SO1002,2024-02-20,C002,Blue Yonder Airlines,P200,Wide Monitor,Accessories,R01,East,3,300.00,200.00
SO1003,2024-03-10,C003,Contoso Retail,P300,Standing Desk,Furniture,R02,West,1,800.00,500.00
SO2001,2025-01-15,C001,Alpine Ski House,P100,Pro Laptop,Devices,R01,East,3,1200.00,900.00
SO2002,2025-02-20,C002,Blue Yonder Airlines,P200,Wide Monitor,Accessories,R01,East,4,300.00,200.00
SO2003,2025-03-10,C003,Contoso Retail,P300,Standing Desk,Furniture,R02,West,2,800.00,500.00
SO2004,2025-03-12,C004,Delta Traders,P200,Wide Monitor,Accessories,R02,West,2,300.00,200.00
```

## Do it

### Inspect before you build

Good agent hygiene: discover before creating. In Copilot Chat (Agent mode):

```
Using the Fabric MCP, inspect the "Contoso Sales Dev" workspace (do not touch
any other workspace). List every item and identify anything related to this
solution: a "ContosoSalesLH" Lakehouse, a transformation notebook, a pipeline,
a "Contoso Sales" semantic model, or a report. For each, report its name,
type, and whether it would collide with the items this tutorial creates.
Summarize what exists and flag name conflicts. Do not create, modify, or
delete anything — this is read-only.
```

### Create the Lakehouse and upload the CSV

Ask Copilot to create the Lakehouse and stage the file through the Fabric MCP:

```
Using the Fabric MCP, in the "Contoso Sales Dev" workspace:
1. Create a Lakehouse named "ContosoSalesLH" (reuse it if one already exists —
   do not create a duplicate). Lakehouse names cannot contain spaces.
2. Upload the local file data/raw/sales.csv to the OneLake path
   Files/contoso/raw/sales.csv in that Lakehouse.
Then confirm the file is staged by listing Files/contoso/raw/ and reporting
the file name and size. Show what you will do before making changes.
```

### Build the transformation

Hand the build to Copilot so the generated code stays visible and reviewable:

```
In the "Contoso Sales Dev" workspace, build the Contoso sales data path with
the fabric-skills guidance. Read the staged CSV at Files/contoso/raw/sales.csv
in the "ContosoSalesLH" Lakehouse and transform it into five Delta tables named
exactly FactSales, DimDate, DimCustomer, DimProduct, and DimRegion (keep these
technical names — do not rename them).

Requirements:
- Create the notebook bound to the "ContosoSalesLH" Lakehouse as its default
  Lakehouse, so relative Files/... paths and saveAsTable resolve against it.
- Read with an explicit schema and explicit data types; do not infer. Read
  Quantity as int and UnitPrice/UnitCost as decimal(18,2) (currency) — not
  double.
- Preserve source values; do not silently coerce or drop data.
- Reject invalid business keys (null OrderId/keys, non-positive Quantity,
  negative UnitPrice or UnitCost) and fail loudly, reporting rejected rows.
- Enforce a unique OrderId in FactSales and consistent dimension attributes.
- Produce these exact columns (integer surrogate DateKey is the join key — do
  not keep OrderDate on the fact):
  - FactSales: OrderId, DateKey (int, yyyyMMdd derived from OrderDate),
    CustomerId, ProductId, RegionId, Quantity (int), UnitPrice (decimal(18,2)),
    UnitCost (decimal(18,2)).
  - DimDate: DateKey (int, yyyyMMdd — joins to FactSales[DateKey]), Date (date —
    used for time intelligence), Year, Quarter, MonthNumber, MonthName,
    YearMonth. Cover every order date in the range.
  - DimCustomer: CustomerId, CustomerName.
  - DimProduct: ProductId, ProductName, Category.
  - DimRegion: RegionId, RegionName.
- Report the row count of every output table.
- Reuse the existing "ContosoSalesLH" Lakehouse and any existing notebook
  instead of creating duplicates.

Generate the notebook and show the code and the proposed changes before
running anything. After I approve and run it, report the actual row counts.
```

Because the notebook is created **bound to `ContosoSalesLH` as its default Lakehouse**, its
`Files/contoso/raw/sales.csv` read and `saveAsTable` writes resolve without extra configuration.
(If you ever open a notebook that isn't bound, set the default Lakehouse first — see
[Run it](#run-it--the-fabric-extension-and-copilot-together) below.) The notebook it produces
should look like the reference implementation below.

```
from pyspark.sql import functions as F
from pyspark.sql import types as T

SOURCE_PATH = "Files/contoso/raw/sales.csv"

sales_schema = T.StructType(
    [
        T.StructField("OrderId", T.StringType(), False),
        T.StructField("OrderDate", T.DateType(), False),
        T.StructField("CustomerId", T.StringType(), False),
        T.StructField("CustomerName", T.StringType(), False),
        T.StructField("ProductId", T.StringType(), False),
        T.StructField("ProductName", T.StringType(), False),
        T.StructField("Category", T.StringType(), False),
        T.StructField("RegionId", T.StringType(), False),
        T.StructField("RegionName", T.StringType(), False),
        T.StructField("Quantity", T.IntegerType(), False),
        T.StructField("UnitPrice", T.DecimalType(18, 2), False),
        T.StructField("UnitCost", T.DecimalType(18, 2), False),
    ]
)

raw_sales = (
    spark.read
    .option("header", True)
    .schema(sales_schema)
    .csv(SOURCE_PATH)
)

required_columns = [
    "OrderId",
    "OrderDate",
    "CustomerId",
    "ProductId",
    "RegionId",
    "Quantity",
    "UnitPrice",
    "UnitCost",
]

invalid_sales = raw_sales.filter(
    F.greatest(
        *[F.col(column).isNull().cast("int") for column in required_columns]
    ) == 1
).unionByName(
    raw_sales.filter(
        (F.col("Quantity") <= 0)
        | (F.col("UnitPrice") < 0)
        | (F.col("UnitCost") < 0)
    )
).dropDuplicates()

invalid_count = invalid_sales.count()
if invalid_count:
    display(invalid_sales)
    raise ValueError(f"Rejected {invalid_count} invalid sales rows")

duplicate_orders = (
    raw_sales.groupBy("OrderId")
    .count()
    .filter(F.col("count") > 1)
)
if duplicate_orders.count():
    display(duplicate_orders)
    raise ValueError("OrderId must be unique in the demo dataset")

def assert_consistent_attribute(source, key_column, attribute_columns):
    conflicts = source.groupBy(key_column).agg(
        *[
            F.countDistinct(attribute).alias(f"{attribute}_value_count")
            for attribute in attribute_columns
        ]
    )

    conflict_filter = None
    for attribute in attribute_columns:
        condition = F.col(f"{attribute}_value_count") > 1
        conflict_filter = condition if conflict_filter is None else conflict_filter | condition

    conflicts = conflicts.filter(conflict_filter)
    if conflicts.count():
        display(conflicts)
        raise ValueError(f"Conflicting attributes found for {key_column}")

assert_consistent_attribute(raw_sales, "CustomerId", ["CustomerName"])
assert_consistent_attribute(raw_sales, "ProductId", ["ProductName", "Category"])
assert_consistent_attribute(raw_sales, "RegionId", ["RegionName"])

dim_customer = raw_sales.select(
    "CustomerId", "CustomerName"
).dropDuplicates(["CustomerId"])

dim_product = raw_sales.select(
    "ProductId", "ProductName", "Category"
).dropDuplicates(["ProductId"])

dim_region = raw_sales.select(
    "RegionId", "RegionName"
).dropDuplicates(["RegionId"])

date_bounds = raw_sales.agg(
    F.min("OrderDate").alias("MinDate"),
    F.max("OrderDate").alias("MaxDate"),
).first()

dim_date = (
    spark.range(1)
    .select(
        F.explode(
            F.sequence(
                F.lit(date_bounds["MinDate"]),
                F.lit(date_bounds["MaxDate"]),
                F.expr("INTERVAL 1 DAY"),
            )
        ).alias("Date")
    )
    .withColumn("DateKey", F.date_format("Date", "yyyyMMdd").cast("int"))
    .withColumn("Year", F.year("Date"))
    .withColumn("Quarter", F.concat(F.lit("Q"), F.quarter("Date")))
    .withColumn("MonthNumber", F.month("Date"))
    .withColumn("MonthName", F.date_format("Date", "MMMM"))
    .withColumn("YearMonth", F.date_format("Date", "yyyy-MM"))
    .select(
        "DateKey",
        "Date",
        "Year",
        "Quarter",
        "MonthNumber",
        "MonthName",
        "YearMonth",
    )
)

fact_sales = raw_sales.select(
    "OrderId",
    F.date_format("OrderDate", "yyyyMMdd").cast("int").alias("DateKey"),
    "CustomerId",
    "ProductId",
    "RegionId",
    "Quantity",
    "UnitPrice",
    "UnitCost",
)

tables = {
    "DimDate": dim_date,
    "DimCustomer": dim_customer,
    "DimProduct": dim_product,
    "DimRegion": dim_region,
    "FactSales": fact_sales,
}

for table_name, dataframe in tables.items():
    (
        dataframe.write
        .format("delta")
        .mode("overwrite")
        .option("overwriteSchema", "true")
        .saveAsTable(table_name)
    )
    print(f"{table_name}: {dataframe.count()} rows")
```

### Test the notebook through the Fabric Data Engineering extension

> **Where the notebook lives.** Copilot created the notebook as an item **in the Fabric workspace
> (cloud)**, not as a file on your disk — so you won't find an `.ipynb` in your local clone yet, and
> the Fabric portal shows it as **uncommitted**. That "uncommitted" is **Fabric Git integration**
> state (the workspace has a change not yet pushed to the `build/contoso-sales` branch), and it is
> separate from your local Git clone. You'll run it here, then commit and pull it in the next two
> sections.

This is where the **Fabric Data Engineering extension** earns its place: you run the workspace
notebook on remote Spark, from inside VS Code, in **VFS mode** — no local copy, no manual download.

1. **Open the Fabric explorer.** In the Activity Bar, select the **Microsoft Fabric** icon and sign
   in if prompted. Expand **Fabric Workspaces (Remote) → Contoso Sales Dev**. You'll see the items
   Copilot created — the **ContosoSalesLH** Lakehouse and the transformation **Notebook**.
2. **Preview the Lakehouse (optional).** Expand **ContosoSalesLH.Lakehouse → Tables/Files** to
   browse data and copy OneLake paths without leaving the editor. Before the run, `Tables` is empty
   and `Files/contoso/raw/sales.csv` is present.
3. **Open the notebook.** Hover the notebook in the explorer and select **Open Notebook Folder**
   (or open it from its authoring page in the portal with **Open in VS Code (Desktop)**). It opens
   in **VFS mode** — edits **auto-sync back to the workspace when you save**, so you're editing the
   real workspace item, not a copy.
4. **Confirm the default Lakehouse.** Expand the notebook's **Dependencies → Lakehouses** and check
   that **ContosoSalesLH** is marked **default**. Copilot bound it at creation, so the relative
   `Files/contoso/raw/sales.csv` read and `saveAsTable` writes resolve. If it isn't set (for a
   notebook created another way), right-click **ContosoSalesLH → Set as Default Lakehouse**.
5. **Select the Spark kernel.** At the top-right of the notebook, choose the kernel and pick
   **Microsoft Fabric Runtime**. This runs cells on the workspace's remote Spark compute (the
   **Jupyter** and **Python** extensions provide the cell UX).
6. **Run all cells** and watch the printed row counts stream in. The first run starts a Spark
   session, so give it a minute.
7. **Inspect the run (optional).** Right-click the notebook and choose **View Recent Runs** to see
   execution history, download stdout/stderr/driver logs, or open the Spark History Server — useful
   if a cell fails.
8. **Confirm the tables materialized.** Back in **ContosoSalesLH.Lakehouse → Tables**, refresh and
   confirm `FactSales` and the four dimensions now exist. (You'll validate the totals with SQL in
   [Verify](#verify) below.)

**How Copilot fits in:** in Agent mode, Copilot generates and refines the notebook cells and can
run them for you through this same surface — you review each cell before it runs — or you edit a
cell yourself and ask Copilot to explain or fix it. The extension supplies the notebook and the
Spark connection; Copilot supplies the authoring and validation.

### Commit the notebook to Git from the workspace

Running the notebook changed the **workspace**, but nothing has reached your repo yet. **You cannot
`git pull` an item that hasn't been committed from the workspace** — until you commit, the
`build/contoso-sales` branch has no notebook to fetch. The Fabric explorer and the notebook editor
let you *run* items but do **not** commit them; committing is a **workspace-level** Git-integration
action. Do it one of two ways:

- **Ask Copilot** (it runs `fab api` against the Git-integration endpoints):

  ```
  Commit the pending changes in the "Contoso Sales Dev" workspace to its
  connected Git branch using the Fabric Git integration API. First call git
  status to list what's uncommitted and read the workspaceHead, then commit all
  changes with mode All and a clear message like "Add sales transformation
  notebook". Afterward, call git status again and confirm the workspace reports
  no pending changes.
  ```

  Under the hood that's `git/status` (to read the uncommitted items and `workspaceHead`) then
  `git/commitToGit` with `mode: All`.
- **Fabric portal (do it by hand once to see it).** Open the **Contoso Sales Dev** workspace in the
  browser. At the top-right, click the **Source control** icon — the badge shows the number of
  changed items. In the **Commit and update** panel, the **Changes** tab lists your notebook with a
  *new* icon. Tick it, type a commit message, and choose **Commit**. The badge returns to **0** when
  the workspace matches the branch. This control is at the **workspace** level — that's why you
  didn't find it inside the notebook or the data-engineering experience.

### See it in source control and pull it locally

The Fabric commit wrote the notebook to the **remote** `build/contoso-sales` branch on GitHub. Now
sync your local clone:

1. In the **solution repo** terminal (or VS Code **Source Control** view), make sure you're on the
   branch and pull:

   ```
   git switch build/contoso-sales
   git pull
   ```

2. In the VS Code **Explorer**, expand `src/fabric/`. The notebook appears as a
   **`<Name>.Notebook/` folder** — not a `.ipynb` — containing:
   - `notebook-content.py` — the notebook source (Fabric's `.py` format with cell markers), the
     file reviewers actually read in a diff.
   - `.platform` — item metadata (display name, type, logical ID).
3. Open `notebook-content.py` to confirm your transformation code is there in readable form. This is
   the reviewable source that flows through the pull request in [Step 9](09-review-in-github.md).

> **Why a folder and not a `.ipynb`?** Fabric stores notebooks in Git as a `.Notebook` item folder
> so diffs are clean text and item metadata travels with the code. The VS Code Fabric extension
> still opens it as a notebook; Git just sees reviewable source.

## Verify

The run should print deterministic row counts:

```
DimDate: 423 rows
DimCustomer: 4 rows
DimProduct: 3 rows
DimRegion: 2 rows
FactSales: 7 rows
```

The date row count covers January 15, 2024 through March 12, 2025, inclusive.

Then confirm the totals against the Lakehouse **SQL analytics endpoint** with the **MSSQL**
extension: in the Fabric explorer, copy the Lakehouse SQL endpoint connection, use
**MS SQL: Connect**, open a new query, and run the statement below — or ask Copilot to run it for
you through the MSSQL tools:

> **Table names are lowercase and case-sensitive here.** Spark's `saveAsTable` registers table
> names in **lowercase** (`factsales`, `dimdate`, …), and the Fabric SQL analytics endpoint uses a
> **case-sensitive** collation — so `dbo.FactSales` fails with *"Invalid object name"* while
> `dbo.factsales` works. **Column** names keep their original case (`OrderId`, `DateKey`, `Quantity`,
> …). The queries below use lowercase table names for that reason. (In the semantic model, DAX is
> case-insensitive and you'll give the tables friendly `FactSales`/`DimDate` display names in
> [Step 7](07-semantic-model.md).)

```
SELECT
    d.[Year],
    d.[Quarter],
    CAST(SUM(f.Quantity * f.UnitPrice) AS decimal(18, 2)) AS Revenue,
    CAST(SUM(f.Quantity * f.UnitCost) AS decimal(18, 2)) AS Cost,
    CAST(SUM(f.Quantity * (f.UnitPrice - f.UnitCost)) AS decimal(18, 2)) AS Margin
FROM dbo.factsales AS f
INNER JOIN dbo.dimdate AS d
    ON d.DateKey = f.DateKey
GROUP BY
    d.[Year],
    d.[Quarter]
ORDER BY
    d.[Year],
    d.[Quarter];
```

Expected rows:

```
2024 | Q1 | 4100.00 | 2900.00 | 1200.00
2025 | Q1 | 7000.00 | 4900.00 | 2100.00
```

Confirm referential integrity — every count must be zero:

```
SELECT 'Customer' AS Dimension, COUNT(*) AS MissingKeys
FROM dbo.factsales AS f
LEFT JOIN dbo.dimcustomer AS d ON d.CustomerId = f.CustomerId
WHERE d.CustomerId IS NULL

UNION ALL

SELECT 'Product', COUNT(*)
FROM dbo.factsales AS f
LEFT JOIN dbo.dimproduct AS d ON d.ProductId = f.ProductId
WHERE d.ProductId IS NULL

UNION ALL

SELECT 'Region', COUNT(*)
FROM dbo.factsales AS f
LEFT JOIN dbo.dimregion AS d ON d.RegionId = f.RegionId
WHERE d.RegionId IS NULL

UNION ALL

SELECT 'Date', COUNT(*)
FROM dbo.factsales AS f
LEFT JOIN dbo.dimdate AS d ON d.DateKey = f.DateKey
WHERE d.DateKey IS NULL;
```

## What to notice

- Copilot crossed from guidance into authenticated **Fabric operations** through the MCP.
- The generated transformation code stayed **visible and reviewable**.
- You validated **schema and row counts**, not just a green job status.

> **Optional — Data Wrangler:** open `sales.csv` in Data Wrangler, apply a visible cleanup,
> and export the generated Pandas code into the notebook to show the profiling experience.

Next: [Step 7 — Build and validate the semantic model](07-semantic-model.md).
