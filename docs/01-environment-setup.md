---
title: 1. Set up your environment
nav_order: 2
---

# Step 1 — Set up your environment

**Goal:** install the CLIs, Python + Fabric tooling, Copilot skills, and VS Code extensions,
then sign in.

**What you'll use:** the `scripts/setup.ps1` helper, plus the `az`, `gh`, and `fab` CLIs.

## Prerequisites

- Windows with [PowerShell 7+](https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-windows).
- [Git for Windows](https://git-scm.com/download/win).
- The [App Installer](https://apps.microsoft.com/detail/9nblggh4nns1) (provides `winget`).
- A GitHub Copilot license with **Agent mode** available.
- Access to a Microsoft Fabric capacity and permission to create workspaces.
- [Power BI Desktop](https://www.microsoft.com/download/details.aspx?id=58494) (Windows) — used in
  [Step 8](08-author-report.md) for the **Desktop Bridge** (live reload + screenshot verification the
  `powerbi-authoring` skill drives). Enable the preview feature **File → Options and settings →
  Options → Preview features → "Enable external tool access to Power BI Desktop through secure local
  APIs"** (on by default), then restart Power BI Desktop.

## Do it

First, get the **tutorial** repo (this repository) — it contains `scripts/setup.ps1`. Clone
it and change into it:

```
gh repo clone howardginsburg/FabricGitHubCopilotTutorial
cd FabricGitHubCopilotTutorial
```

> This is the **tutorial** repo. Later, in [Step 3](03-connect-github.md), you'll create a
> **separate** empty repo for the Fabric solution itself. Keep the two distinct.

Run the setup script from the repository root. It is idempotent, so it is safe to re-run.

```
pwsh -File scripts/setup.ps1
```

The script:

- Installs (via `winget`, only if missing) Azure CLI, GitHub CLI, GitHub Copilot CLI, Node.js 22 LTS, and Python 3.13.
- Checks for the **.NET 10 SDK** (which provides `dnx` for the Data Factory MCP in [Step 11](11-orchestrate.md)) and installs it via `winget` if no 10.x SDK is found.
- Installs the **Fabric CLI (`fab`) globally with pipx**, in its own isolated environment but on your PATH — so it works in every repo you open, not just this one.
- Installs the `fabric-skills` and `powerbi-authoring` Copilot plugins.
- Installs the **Power BI authoring CLIs** the `powerbi-authoring` skill drives, as global npm
  packages: `@microsoft/powerbi-report-authoring-cli` (the `powerbi-report-author` command — edits
  and validates PBIR) and `@microsoft/powerbi-desktop-bridge-cli` (the `powerbi-desktop` command —
  the Desktop Bridge that reloads and screenshots Power BI Desktop). Used in [Step 8](08-author-report.md).
- Points you at the recommended VS Code extensions.

This is a **one-time workstation setup**. Run it once and `fab`, `az`, `gh`, and `copilot` are
available in any folder afterward — you do not re-run it per project.

> **Your default Python is untouched.** The Fabric CLI declares support for Python < 3.14, so
> pipx runs it on an isolated Python 3.13 behind the scenes. Your interactive `python` can stay
> 3.14 or newer for everything else. Pass `-SkipCli` if the CLIs are already installed, or
> `-PythonVersion 3.12` to pin the Fabric CLI's hidden interpreter to another supported version
> (3.10–3.13).
>
> The `fabric-cicd` library is **not** installed here — it's a per-project dependency handled by
> each solution repo's CI (see [Step 9](09-review-in-github.md)).

If a CLI was just installed, open a **new terminal** so `PATH` refreshes before continuing. A
long-running VS Code process can retain its old environment even after a new terminal is opened.
If `Get-Command fab` still fails, refresh the current PowerShell process from the persisted PATH:

```
$env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
    [Environment]::GetEnvironmentVariable('Path', 'User')
Get-Command fab
```

On Windows, pipx normally exposes the Fabric CLI at `$HOME\.local\bin\fab.exe`. If that file
exists, the pipx environment is installed correctly; do not reinstall it just because the current
process has a stale PATH.

### Install the VS Code extensions

Open the folder in VS Code, open the Command Palette, and run
**Extensions: Show Recommended Extensions**. In the Extensions view, use the download icon on
the **Workspace Recommendations** heading to install them all. The recommended set is defined
in `.vscode/extensions.json`.

### Sign in

Authentication is intentionally not done by the script. Sign in when ready:

```
az login
gh auth login
fab auth login
copilot        # then run /login on first launch
```

Run `fab auth login` in a real terminal window. Redirected or non-interactive agent shells may
fail with `No Windows console found`. Confirm the result with:

```
fab auth status
```

Also sign in to the Microsoft Fabric extension and Power BI tools through the VS Code
**Accounts** menu when prompted.

## Verify

```
node --version
az version --output table
gh --version
copilot --version
copilot plugin list       # fabric-skills and powerbi-authoring appear
fab --version             # fab version 1.7.0 — works from any folder
powerbi-report-author --version   # PBIR authoring/validation CLI (Step 8)
powerbi-desktop --version         # Power BI Desktop Bridge CLI (Step 8)
```

Confirm these too, since later steps depend on them:

- The required first-party extensions are enabled.
- Fabric MCP and Power BI Modeling MCP tools appear in the Copilot **tools** list.
- Microsoft Learn MCP is connected.
- GitHub tools are connected with only the permissions you need.

## How Copilot knows about these tools

This tutorial repo ships a `.github/copilot-instructions.md` that tells
Copilot what's installed (the `fab`, `az`, and `gh` CLIs) and which tool to use for each task —
for example, that **workspace and capacity operations use the `fab` CLI**, not an MCP. Copilot
loads this file automatically when you work in the folder, in **both** surfaces below. Without it
(for example, starting Copilot in an unrelated empty folder), the agent has no idea `fab` exists
and will say it can't create a workspace.

Two Copilot surfaces are used in this tutorial:

- **VS Code Copilot Chat (Agent mode)** — has the Fabric MCP, Power BI Modeling MCP, and
  Microsoft Learn MCP for item-level and model work. This is the surface the steps lead with.
- **The standalone `copilot` CLI** — has the Copilot skills but **not** the VS Code Fabric MCP;
  there Copilot drives Fabric by running `fab` commands. It reads the same
  `.github/copilot-instructions.md`.

In either surface, always keep the tutorial folder open so the instructions load, and approve the
`fab`/`gh` commands the agent proposes.

Next: [Step 2 — Create a Fabric workspace](02-create-fabric-workspace.md).
