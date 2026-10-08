#requires -Version 7.0
<#
.SYNOPSIS
    One-time workstation setup for building Fabric and Power BI solutions with GitHub Copilot.

.DESCRIPTION
    Run this once per workstation. It installs everything machine-wide so the tools are
    available in every repository you work in afterward — you do not re-run it per project.

    It performs these steps, echoing what it does at each one:
      1. Verify prerequisites (winget).
      2. Install the base CLIs (Azure CLI, GitHub CLI, Node.js, Python) via winget.
      3. Ensure the .NET 10 SDK (provides `dnx` for the Data Factory MCP) — install only if
         no 10.x SDK is already present.
      4. Install the Fabric CLI (`fab`) via pipx: an isolated environment for the tool that is
         still exposed globally on PATH and pinned to a supported Python (< 3.14). It never
         conflicts with a project's Python and works in any folder.
      5. Install the GitHub Copilot CLI via npm.
      6. Install the Fabric Copilot skills globally (`copilot plugin install`).
      7. Point you at the recommended VS Code extensions (.vscode/extensions.json).

    Per-project Python dependencies (for example `fabric-cicd`, used by a deployment script)
    are NOT installed here. They belong to each solution repository's requirements.txt and are
    installed by that repository's CI.

    The script is idempotent: it skips anything already present and reports a summary at the end.

    Authentication is intentionally not performed here. Sign in after setup with
    `az login`, `gh auth login`, and `fab auth login`.

.PARAMETER SkipCli
    Skip installing the winget-provided CLIs and the .NET 10 SDK (steps 2 and 3). Use this when
    those are already installed.

.PARAMETER PythonVersion
    The supported Python version pipx uses for the Fabric CLI's isolated environment
    (3.10-3.13). Defaults to 3.13, the newest version the Fabric tooling supports. This does
    NOT change your workstation's default Python — you can keep 3.14 or newer for everything
    else; only the hidden environment behind `fab` uses this version.

.EXAMPLE
    pwsh -File scripts/setup.ps1
#>

[CmdletBinding()]
param(
    [switch]$SkipCli,
    [string]$PythonVersion = '3.13'
)

$ErrorActionPreference = 'Stop'
$script:Summary = [System.Collections.Generic.List[object]]::new()
$script:StepNumber = 0
$script:TotalSteps = 7

# ---------------------------------------------------------------------------
# Output helpers — keep every step consistent and easy to scan.
# ---------------------------------------------------------------------------
function Write-Step {
    param([string]$Title, [string]$Detail)
    $script:StepNumber++
    Write-Host ""
    Write-Host ("[{0}/{1}] {2}" -f $script:StepNumber, $script:TotalSteps, $Title) -ForegroundColor Cyan
    if ($Detail) { Write-Host "        $Detail" -ForegroundColor DarkGray }
}

function Write-Action { param([string]$Message) Write-Host "  -> $Message" }
function Write-Ok     { param([string]$Message) Write-Host "  [ok]   $Message" -ForegroundColor Green }
function Write-Skip   { param([string]$Message) Write-Host "  [skip] $Message" -ForegroundColor DarkGray }
function Write-Note   { param([string]$Message) Write-Host "  [warn] $Message" -ForegroundColor Yellow }

function Add-Result {
    param([string]$Name, [string]$State)
    $script:Summary.Add([pscustomobject]@{ Name = $Name; State = $State })
}

# ---------------------------------------------------------------------------
# Utilities.
# ---------------------------------------------------------------------------
function Update-SessionPath {
    # winget/npm installs update the persisted PATH but not the current process.
    $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = @($machine, $user | Where-Object { $_ }) -join ';'
}

function Resolve-PythonCommand {
    <#
        Returns an array (exe + args) that launches the requested Python major.minor version,
        or $null if it cannot be found. Prefers the Windows `py` launcher so we pin the version
        regardless of what the bare `python` command resolves to.
    #>
    param([Parameter(Mandatory)][string]$Version)

    if (Get-Command py -ErrorAction SilentlyContinue) {
        if (& py --list 2>&1 | Select-String -Pattern "-V:$([regex]::Escape($Version))\b" -Quiet) {
            return @('py', "-$Version")
        }
    }

    foreach ($name in "python$Version", 'python') {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue
        if ($cmd -and ((& $cmd.Source --version 2>&1) -match "Python\s+$([regex]::Escape($Version))(\.|$)")) {
            return @($cmd.Source)
        }
    }

    return $null
}

function Install-WingetPackage {
    param(
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][string]$Name
    )

    Write-Action "Checking for $Name ($Id)..."
    if (winget list --id $Id --exact --accept-source-agreements 2>$null | Select-String -SimpleMatch $Id -Quiet) {
        Write-Skip "$Name is already installed."
        Add-Result $Name 'already installed'
        return
    }

    Write-Action "Installing $Name with winget..."
    winget install --id $Id --exact --silent `
        --accept-package-agreements --accept-source-agreements --disable-interactivity
    if ($LASTEXITCODE -eq 0) {
        Write-Ok "$Name installed."
        Add-Result $Name 'installed'
    } else {
        Write-Note "winget returned exit code $LASTEXITCODE for $Name."
        Add-Result $Name "FAILED (exit $LASTEXITCODE)"
    }
}

# ---------------------------------------------------------------------------
# Guard: the Fabric tooling declares requires_python <3.14, so the isolated interpreter behind
# `fab` must be 3.13 or older. Your workstation's default Python is unaffected.
# ---------------------------------------------------------------------------
if ([version]$PythonVersion -ge [version]'3.14') {
    throw "The Fabric CLI does not support Python $PythonVersion (ms-fabric-cli and fabric-cicd require < 3.14). Use 3.13 or older for -PythonVersion. Your default Python can still be 3.14+; pipx isolates the Fabric CLI on its own interpreter."
}

$workspaceRoot = Split-Path -Parent $PSScriptRoot

Write-Host "Fabric + Power BI with GitHub Copilot — workstation setup" -ForegroundColor White
Write-Host "Installs machine-wide tools so every repo you open just works. Idempotent; safe to re-run." -ForegroundColor DarkGray

# ===========================================================================
# Step 1 — Prerequisites
# ===========================================================================
Write-Step "Verify prerequisites" "Confirm winget is available before installing anything."
if (Get-Command winget -ErrorAction SilentlyContinue) {
    Write-Ok "winget found."
} elseif ($SkipCli) {
    Write-Skip "winget not found, but -SkipCli was passed; continuing without winget installs."
} else {
    throw "winget is not available. Install 'App Installer' from the Microsoft Store, then re-run this script."
}

# ===========================================================================
# Step 2 — Base CLIs
# ===========================================================================
Write-Step "Install base CLIs" "Azure CLI, GitHub CLI, Node.js LTS, and Python 3.13 (via winget)."
if ($SkipCli) {
    Write-Skip "-SkipCli passed; leaving the base CLIs as-is."
    Add-Result 'Base CLIs' 'skipped (-SkipCli)'
} else {
    Install-WingetPackage -Id 'Microsoft.AzureCLI' -Name 'Azure CLI'
    Install-WingetPackage -Id 'GitHub.cli'         -Name 'GitHub CLI'
    Install-WingetPackage -Id 'OpenJS.NodeJS.LTS'  -Name 'Node.js LTS'
    Install-WingetPackage -Id 'Python.Python.3.13' -Name 'Python 3.13'
    Update-SessionPath
}

# ===========================================================================
# Step 3 — .NET 10 SDK (for `dnx` / Data Factory MCP)
# ===========================================================================
Write-Step ".NET 10 SDK" "Provides 'dnx' for the Data Factory MCP (preview). Installed only if no 10.x SDK exists."
if ($SkipCli) {
    Write-Skip "-SkipCli passed; not touching the .NET SDK."
    Add-Result '.NET 10 SDK' 'skipped (-SkipCli)'
} else {
    Write-Action "Checking installed .NET SDKs..."
    $dotnet = Get-Command dotnet -ErrorAction SilentlyContinue
    $hasDotNet10 = $dotnet -and (& dotnet --list-sdks 2>$null | Select-String -Pattern '^\s*10\.' -Quiet)
    if ($hasDotNet10) {
        Write-Skip "A .NET 10.x SDK is already installed (may be from Visual Studio or a standalone installer)."
        Add-Result '.NET 10 SDK' 'already installed'
    } else {
        Write-Action "No 10.x SDK found."
        Install-WingetPackage -Id 'Microsoft.DotNet.SDK.10' -Name '.NET 10 SDK'
    }
    Update-SessionPath
}

# ===========================================================================
# Step 4 — Fabric CLI (fab) via pipx
# ===========================================================================
Write-Step "Install the Fabric CLI (fab)" "Global via pipx: isolated on Python $PythonVersion, but on PATH in every folder."

# The pinned version comes from requirements.txt so the CLI and CI stay in lockstep.
$requirementsPath = Join-Path $PSScriptRoot 'requirements.txt'
$fabPin = (Get-Content $requirementsPath | Where-Object { $_ -match '^\s*ms-fabric-cli\b' } | Select-Object -First 1).Trim()
if (-not $fabPin) { $fabPin = 'ms-fabric-cli' }
Write-Action "Target package: $fabPin (pinned in scripts/requirements.txt)."

Write-Action "Locating a Python $PythonVersion interpreter..."
$pythonCmd = Resolve-PythonCommand -Version $PythonVersion
if (-not $pythonCmd) {
    throw "Python $PythonVersion was not found. If it was just installed, open a new terminal so PATH refreshes, then re-run. The Fabric CLI requires Python < 3.14."
}
$pyExe = $pythonCmd[0]
$pyArgs = @()
if ($pythonCmd.Length -gt 1) { $pyArgs = $pythonCmd[1..($pythonCmd.Length - 1)] }
$pythonPath = (& $pyExe @pyArgs -c "import sys; print(sys.executable)").Trim()
Write-Action "Using interpreter: $pythonPath"

# Ensure pipx is available (installed into the supported Python, then on PATH).
if (Get-Command pipx -ErrorAction SilentlyContinue) {
    Write-Skip "pipx already available."
} else {
    Write-Action "Installing pipx into the Python $PythonVersion user site..."
    & $pythonPath -m pip install --user --upgrade pipx | Out-Host
    & $pythonPath -m pipx ensurepath | Out-Host
    Update-SessionPath
}

# Resolve how to invoke pipx: prefer the on-PATH exe, else run it as a module.
$pipxCmd = Get-Command pipx -ErrorAction SilentlyContinue
$script:pipxExe = if ($pipxCmd) { $pipxCmd.Source } else { $null }
$script:pythonPath = $pythonPath

function Invoke-Pipx {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$PipxArgs)
    if ($script:pipxExe) { & $script:pipxExe @PipxArgs }
    else { & $script:pythonPath -m pipx @PipxArgs }
}

if (Invoke-Pipx list 2>&1 | Select-String -SimpleMatch 'ms-fabric-cli' -Quiet) {
    Write-Action "Fabric CLI already present; reinstalling at the pinned version..."
    # The pipx venv already exists on the correct interpreter, so --python is unnecessary here
    # (pipx ignores it with --force and would warn otherwise).
    Invoke-Pipx install --force $fabPin | Out-Host
} else {
    Write-Action "Installing the Fabric CLI into a new pipx environment..."
    Invoke-Pipx install --python $pythonPath $fabPin | Out-Host
}
Update-SessionPath
Write-Ok "Fabric CLI (fab) available on PATH."
Add-Result 'Fabric CLI (fab, via pipx)' 'installed'

# ===========================================================================
# Step 5 — GitHub Copilot CLI
# ===========================================================================
Write-Step "Install the GitHub Copilot CLI" "Global npm package (@github/copilot)."
if (-not (Get-Command npm -ErrorAction SilentlyContinue)) { Update-SessionPath }
if (Get-Command npm -ErrorAction SilentlyContinue) {
    Write-Action "Running: npm install -g @github/copilot"
    npm install -g '@github/copilot' | Out-Host
    Update-SessionPath
    Write-Ok "GitHub Copilot CLI installed."
    Add-Result 'GitHub Copilot CLI' 'installed'
} else {
    Write-Note "npm not found. Open a new terminal after Node.js installs, then re-run this script."
    Add-Result 'GitHub Copilot CLI' 'SKIPPED (npm missing)'
}

# ===========================================================================
# Step 5b — Power BI report-authoring CLIs (for the powerbi-authoring skill)
# ===========================================================================
Write-Step "Install the Power BI authoring CLIs" "Global npm packages the powerbi-authoring skill drives: powerbi-report-author and powerbi-desktop (Desktop Bridge)."
if (-not (Get-Command npm -ErrorAction SilentlyContinue)) { Update-SessionPath }
if (Get-Command npm -ErrorAction SilentlyContinue) {
    Write-Action "Running: npm install -g @microsoft/powerbi-report-authoring-cli@latest @microsoft/powerbi-desktop-bridge-cli@latest"
    npm install -g '@microsoft/powerbi-report-authoring-cli@latest' '@microsoft/powerbi-desktop-bridge-cli@latest' | Out-Host
    Update-SessionPath
    Write-Ok "Power BI authoring CLIs installed (powerbi-report-author, powerbi-desktop)."
    Add-Result 'Power BI authoring CLIs' 'installed'
} else {
    Write-Note "npm not found. Open a new terminal after Node.js installs, then re-run this script."
    Add-Result 'Power BI authoring CLIs' 'SKIPPED (npm missing)'
}

# ===========================================================================
# Step 6 — Fabric Copilot skills
# ===========================================================================
Write-Step "Install the Fabric Copilot skills" "Global plugins: fabric-skills and powerbi-authoring."
if (Get-Command copilot -ErrorAction SilentlyContinue) {
    Write-Action "Ensuring the fabric-collection marketplace is registered..."
    if (copilot plugin marketplace list 2>&1 | Select-String -SimpleMatch 'fabric-collection' -Quiet) {
        Write-Skip "Marketplace 'fabric-collection' already registered."
    } else {
        copilot plugin marketplace add microsoft/skills-for-fabric | Out-Host
    }

    foreach ($plugin in 'fabric-skills@fabric-collection', 'powerbi-authoring@fabric-collection') {
        $name = $plugin.Split('@')[0]
        # The deprecated 'skills-for-fabric' alias resolves to the same bundle as 'fabric-skills';
        # treat either as already installed.
        $alreadyInstalled = copilot plugin list 2>&1 |
            Select-String -SimpleMatch @($plugin, 'skills-for-fabric@fabric-collection') -Quiet
        if ($alreadyInstalled) {
            Write-Skip "$name already installed."
        } else {
            Write-Action "Installing $name..."
            copilot plugin install $plugin 2>&1 | Out-Host
        }
    }
    Write-Ok "Fabric Copilot skills ready."
    Add-Result 'Fabric Copilot skills' 'installed'
} else {
    Write-Note "copilot command not found. Open a new terminal after Node.js installs, then re-run."
    Add-Result 'Fabric Copilot skills' 'SKIPPED (copilot missing)'
}

# ===========================================================================
# Step 7 — VS Code extensions
# ===========================================================================
Write-Step "VS Code extensions" "Recommended, not force-installed; you install them from VS Code."
$recPath = Join-Path $workspaceRoot '.vscode\extensions.json'
if (Test-Path $recPath) {
    Write-Action "Recommendations live in .vscode\extensions.json."
    Write-Action "In VS Code: Command Palette -> 'Extensions: Show Recommended Extensions' -> Install Workspace Recommended Extensions."
    Add-Result 'VS Code extensions' 'recommended (.vscode\extensions.json)'
} else {
    Write-Note ".vscode\extensions.json not found; extension recommendations are unavailable."
    Add-Result 'VS Code extensions' 'MISSING recommendations file'
}

# ===========================================================================
# Report
# ===========================================================================
function Show-Version {
    param([string]$Label, [scriptblock]$Command)
    try {
        $value = (& $Command 2>&1 | Select-Object -First 1)
        Write-Host ("  {0,-16} {1}" -f $Label, $value)
    } catch {
        Write-Host ("  {0,-16} not found" -f $Label) -ForegroundColor DarkGray
    }
}

Write-Host ""
Write-Host "Installed tool versions" -ForegroundColor Cyan
Show-Version 'Python' { & $pythonPath --version }
Show-Version 'Node.js' { node --version }
Show-Version 'Azure CLI' { az version --output tsv 2>$null }
Show-Version 'GitHub CLI' { gh --version }
Show-Version 'Copilot CLI' { copilot --version }
Show-Version 'Fabric CLI' { fab --version 2>$null }
Show-Version '.NET SDK' { dotnet --version 2>$null }

Write-Host ""
Write-Host "Setup summary" -ForegroundColor Cyan
$pad = ($script:Summary.Name | Measure-Object -Maximum -Property Length).Maximum
foreach ($row in $script:Summary) {
    $color = if ($row.State -like 'FAILED*' -or $row.State -like 'MISSING*') { 'Red' }
             elseif ($row.State -like 'SKIPPED*' -or $row.State -like 'skipped*') { 'Yellow' }
             else { 'Gray' }
    Write-Host ("  {0} {1}" -f ($row.Name.PadRight($pad)), $row.State) -ForegroundColor $color
}

Write-Host ""
Write-Host "Next steps" -ForegroundColor Yellow
Write-Host "  1. Sign in:"
Write-Host "       az login"
Write-Host "       gh auth login"
Write-Host "       fab auth login"
Write-Host "       copilot   (then /login)"
Write-Host "  2. Install the recommended VS Code extensions:"
Write-Host "       Command Palette -> Extensions: Show Recommended Extensions -> Install Workspace Recommended Extensions"
Write-Host ""
Write-Host "This was a one-time workstation setup. 'fab', 'az', 'gh', and 'copilot' now work in any" -ForegroundColor DarkGray
Write-Host "folder. If a command isn't found yet, open a new terminal so PATH refreshes." -ForegroundColor DarkGray
