---
title: 9. Review through GitHub
nav_order: 10
---

# Step 9 — Review through GitHub

**Goal:** with the notebook, model, and report already on your feature branch from Steps 6–8, add
automated checks, review the whole change with Copilot, and open a pull request into `main` — so
Fabric and Power BI changes follow the same review discipline as application code.

**What Copilot uses:** Copilot to review the change and **generate all the CI** (pinned
requirements, validation scripts, and the workflow), the **GitHub** tools and `git`/`gh` to commit
and open the PR, and **GitHub Actions** + the **GitHub Pull Requests** extension to run and surface
the checks.

## Where you are

Everything in this step happens in the **solution repo** (`contoso-sales-fabric`) open in VS Code, on
the **`build/contoso-sales`** branch — not the tutorial repo. Use that window's integrated terminal.

**What's already committed to the branch** (you don't re-commit these):

- The **notebook** and **semantic model** — committed via **Fabric Git integration** in
  [Step 6](06-build-data-path.md) and [Step 7](07-semantic-model.md) (commit the workspace →
  `git pull`), so they're already on the remote branch under `src/fabric/`.
- The **report PBIR** — committed with plain `git` in [Step 8](08-author-report.md).

**What's still local and gets committed in this step:** the repo instructions
(`.github/copilot-instructions.md` from [Step 4](04-clone-and-open.md), if you didn't already
commit it), a `.gitignore`, the sample CSV (`data/raw/sales.csv`), the CI files you add below
(`scripts/requirements.txt`, `scripts/validate_*.py`, `.github/workflows/validate.yml`), and any
README edits. Machine-local files (`.vscode/`, Python `__pycache__/`, PBIP local settings) are
excluded by the `.gitignore`, so they won't be committed.

## Do it

### 1. Review the whole change with Copilot

Have Copilot review everything on the branch — the already-committed Fabric items plus your local
additions — by diffing the branch against `main`:

```
Review this solution branch (build/contoso-sales) as a Fabric and Power BI pull
request. Using the GitHub tools and git, diff the branch against main (include
both committed changes and uncommitted local files) and summarize it by solution
layer: ingestion (data/raw/sales.csv, OneLake), transformation (notebook + Delta
tables), semantic model (TMDL under src/fabric), report (PBIR under src/fabric),
and deployment/CI (workflows, scripts). For each layer give a concise
what-and-why.

Then flag only high-confidence risks: correctness bugs, security issues (secrets,
connection strings), data-quality problems, and breaking changes. Explicitly
check for hard-coded workspace/capacity IDs and any secret material. Ignore
style-only and formatting suggestions. Do not modify or stage any files — this is
a review.
```

### 2. Have Copilot build the CI

Instead of hand-creating the CI files, have Copilot generate all of them — the pinned requirements,
both validation scripts, and the workflow — in one prompt:

```
In this solution repo, create the CI that validates every pull request. Build
these files:

1. scripts/requirements.txt — pin exactly:
   fabric-cicd==1.3.0
   ms-fabric-cli==1.7.0

2. scripts/validate_demo_data.py — reads data/raw/sales.csv and asserts the demo
   invariants: 7 rows; unique OrderId; Quantity > 0 and UnitPrice/UnitCost >= 0;
   grand totals Revenue 11,100 and Cost 7,800. Exit non-zero with a clear
   message on any failure.

3. scripts/validate_fabric_definitions.py — takes a path arg (src/fabric) and
   checks each Fabric item folder has its required definition files and a
   .platform file (Notebook: notebook-content.py; SemanticModel:
   definition.pbism + definition/; Report: definition.pbir + definition/), and
   parses every JSON. Exit non-zero for: missing required files, invalid JSON,
   or unresolved git merge markers. Also scan for hard-coded workspace/capacity
   GUIDs (e.g. OneLake URLs, notebook lakehouse bindings) but treat these as
   WARNINGS only (print them, do not fail) — Direct Lake models and notebook
   bindings legitimately carry the dev workspace/lakehouse IDs, which are
   parameterized at deploy time (Step 10). Exit non-zero only on the structural
   problems above.

4. .github/workflows/validate.yml — runs on pull_request to main and
   workflow_dispatch, with contents: read permissions. On ubuntu-latest: checkout,
   set up Python 3.13 with pip cache, install scripts/requirements.txt, run both
   validation scripts (passing src/fabric to the definitions one), then grep src
   and scripts for secret/connection-string patterns (client_secret, password,
   DefaultEndpointsProtocol=, AccountKey=) and fail if any are found.

5. .gitignore — ignore machine-local and generated files so they never get
   committed: Python artifacts (__pycache__/, *.pyc, .venv/), editor config
   (.vscode/), and PBIP local settings (**/.pbi/localSettings.json).

Keep the Python scripts dependency-light (standard library only) and runnable as
`python scripts/<name>.py`. Show me each file before writing it, then create them.
```

Copilot produces a workflow like this — skim it so you know what the checks do:

```
name: Validate Fabric solution

on:
  pull_request:
    branches:
      - main
  workflow_dispatch:

permissions:
  contents: read

jobs:
  validate:
    runs-on: ubuntu-latest

    steps:
      - name: Check out source
        uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.13"
          cache: pip

      - name: Install validation dependencies
        run: python -m pip install --requirement scripts/requirements.txt

      - name: Validate demo data
        run: python scripts/validate_demo_data.py

      - name: Validate Fabric item definitions
        run: python scripts/validate_fabric_definitions.py src/fabric

      - name: Scan for environment-specific identifiers
        shell: bash
        run: |
          if grep --recursive --line-number --extended-regexp \
            '(client_secret|password|DefaultEndpointsProtocol=|AccountKey=)' \
            src scripts; then
            echo "Potential secret or connection string found."
            exit 1
          fi
```

> JSON parsing alone does **not** validate PBIR or a semantic model. The scripts above catch
> structural problems; deeper checks (TMDL diagnostics, PBIR validation via the Power BI authoring
> plugin) are listed under [Suggested quality gates](#suggested-quality-gates) below.

> **Expected: your Fabric items contain dev workspace/lakehouse GUIDs.** A Direct Lake model
> serializes its OneLake source as a literal URL with the workspace and lakehouse GUIDs (see
> `Contoso Sales.SemanticModel/definition/expressions.tmdl`), and the notebook carries a
> `default_lakehouse_workspace_id`. That's how Git integration represents the binding — every real
> Direct Lake solution has these. The definitions check therefore **reports** them as warnings but
> does **not** fail on them; the hard secret/connection-string grep is the real gate. These dev IDs
> are handled at deploy time by `fabric-cicd` parameterization — see
> [Step 10](10-deploy.md#parameterize-environment-specific-ids).

### 3. Have Copilot commit, push, and open the PR

The Fabric items under `src/fabric` are already committed. With `.gitignore` now filtering out
machine-local files (editor config, Python artifacts, PBIP local settings), everything else that's
outstanding is intended solution content — so stage it all in one sweep and open the PR:

```
Using git and the GitHub tools: check git status, then stage all outstanding
changes with `git add -A` (the .gitignore excludes machine-local files, and
src/fabric is already committed so nothing changes there). This picks up the repo
instructions (.github/copilot-instructions.md), the workflow, .gitignore, the
README, data/, and scripts/. Commit with the message "Add repo instructions,
sample data, and CI" and push to build/contoso-sales. Then open a pull request
into main titled "Contoso sales solution" with a body summarizing the data path,
semantic model, and executive report. Report the PR URL and check status.
```

For reference, that's equivalent to running:

```
git add -A
git commit -m "Add repo instructions, sample data, and CI"
git push
gh pr create --base main --head build/contoso-sales `
  --title "Contoso sales solution" `
  --body "Data path, semantic model, and executive report."
```

> **Run `git status` first.** By this point everything outstanding is intended — including the
> `.github/copilot-instructions.md` you created in [Step 4](04-clone-and-open.md) if it wasn't
> committed yet. If you see a machine-local file you don't want (e.g. `.vscode/`), it should be in
> `.gitignore` rather than committed.

> **Check sync rather than assuming it (Fabric UI).** Open **Contoso Sales Dev → Source control**.
> The CI files outside `/src/fabric` do not become workspace items, but earlier item changes —
> including the report pushed in Step 8 — can still be waiting under **Updates**. Inspect those
> changes and any uncommitted workspace edits before **Update all**; resolve conflicts deliberately.
> Git integration does not automatically apply a push, and a push containing only repo plumbing
> does not prove that the workspace has no pending item updates.

Opening the PR triggers `validate.yml`. Watch the checks in the **GitHub Pull Requests** extension,
with `gh pr checks`, or just ask Copilot to report them.

### 4. Review the checks, then merge

The PR isn't done until it's reviewed and merged — merging to `main` is what
[Step 10](10-deploy.md) deploys from. In the **GitHub Pull Requests** extension (or on GitHub):

1. **Read the diff** — the notebook (`notebook-content.py`), the semantic model (TMDL under
   `Contoso Sales.SemanticModel/`), and the report (PBIR) all show as readable source. This is the
   payoff of committing Fabric items as text: a normal code review.
2. **Confirm the checks are green** — `validate.yml` should pass (the two dev-ID warnings don't fail
   it; see the note above). If a check is red, fix it on the branch, commit, and push — the PR
   re-runs automatically.
3. **Merge to `main`.** Ask Copilot, or run it yourself:

   ```
   Merge the "Contoso sales solution" pull request into main once its checks pass,
   using a squash merge, and confirm the merge completed.
   ```

   Equivalent CLI:

   ```
   gh pr merge --squash --delete-branch=false
   ```

4. **Sync `main` locally** so your clone matches:

   ```
   git switch main
   git pull
   ```

`main` now holds the reviewed solution — the source [Step 10](10-deploy.md) deploys to a separate
**Contoso Sales Test** workspace. Dev remains connected to `build/contoso-sales`; switching your
local clone to `main` does not change that connection.

## Suggested quality gates

- Notebook/Python syntax and targeted tests.
- SQL project build when Fabric SQL is included.
- TMDL diagnostics and semantic-model best-practice checks.
- DAX query validation.
- PBIR structural validation.
- Detection of environment-specific identifiers and secrets.
- Standard GitHub dependency and secret scanning.

## Verify

- The pull request explains business and technical impact.
- Reviewers see readable **TMDL and PBIR** diffs.
- GitHub Actions reports clear validation results.
- A failed check can be diagnosed and corrected from VS Code, then pushed.

## What to notice

- Copilot **built the CI itself** — scripts and workflow — then committed and opened the PR, yet the
  agent **accelerates** review without bypassing it.
- GitHub captures approvals and quality evidence.
- Fabric and Power BI changes use the same branch-and-PR discipline as app code.

Next: [Step 10 — Deploy through Fabric CI/CD](10-deploy.md).
