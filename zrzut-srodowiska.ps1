<#
.SYNOPSIS
    Zrzut srodowiska do JSON: winget, pip, npm, rozszerzenia Cursor/VS Code, obrazy Docker.
    Ten plik ma byc czytelny dla czlowieka i dla AI - poprawiasz JSON i masz kopie srodowiska.
#>
$ErrorActionPreference = "SilentlyContinue"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $scriptDir) { $scriptDir = (Get-Location).Path }

function Refresh-Path {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
}
Refresh-Path

function Get-CmdOutput {
    param([string]$FilePath, [string[]]$Arguments)
    if (-not (Get-Command $FilePath -ErrorAction SilentlyContinue)) { return $null }
    try {
        $out = & $FilePath @Arguments 2>$null
        return $out
    } catch { return $null }
}

Write-Host "Zrzut srodowiska (winget / Python / npm / AI IDE / Docker)..." -ForegroundColor Cyan

# --- Winget ---
$wingetExportPath = Join-Path $scriptDir "winget-export.json"
$wingetPackages = @()
if (Get-Command winget -ErrorAction SilentlyContinue) {
    winget export --output $wingetExportPath --accept-source-agreements --include-versions | Out-Null
    if (Test-Path $wingetExportPath) {
        try {
            $wx = Get-Content $wingetExportPath -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($src in @($wx.Sources)) {
                foreach ($pkg in @($src.Packages)) {
                    $wingetPackages += [PSCustomObject]@{
                        Name    = $pkg.PackageIdentifier
                        Id      = $pkg.PackageIdentifier
                        Version = $pkg.Version
                        Checked = $true
                    }
                }
            }
        } catch {}
    }
}

# --- Python / pip ---
$pipPkgs = @()
$py = $null
foreach ($c in @("py", "python", "python3")) {
    if (Get-Command $c -ErrorAction SilentlyContinue) { $py = $c; break }
}
if ($py) {
    $freeze = & $py -m pip freeze 2>$null
    foreach ($line in @($freeze)) {
        if ($line -match "^([^=\s]+)==(.+)$") {
            $pipPkgs += [PSCustomObject]@{ Name = $Matches[1]; Version = $Matches[2] }
        }
    }
    $reqPath = Join-Path $scriptDir "python-requirements.txt"
    @($freeze) | Set-Content -Path $reqPath -Encoding UTF8
}

# --- npm global ---
$npmPkgs = @()
if (Get-Command npm -ErrorAction SilentlyContinue) {
    $npmJson = npm list -g --depth=0 --json 2>$null
    try {
        $n = $npmJson | ConvertFrom-Json
        foreach ($dep in $n.dependencies.PSObject.Properties) {
            $npmPkgs += [PSCustomObject]@{ Name = $dep.Name; Version = $dep.Value.version }
        }
    } catch {}
}

# --- Cursor / VS Code extensions ---
function Get-IdeExtensions([string]$cli, [string]$extDir) {
    $list = @()
    if ($cli -and (Get-Command $cli -ErrorAction SilentlyContinue)) {
        $rows = & $cli --list-extensions --show-versions 2>$null
        foreach ($r in @($rows)) {
            if ($r -match "^(.+)@(.+)$") {
                $list += [PSCustomObject]@{ Id = $Matches[1]; Version = $Matches[2] }
            } elseif ($r) {
                $list += [PSCustomObject]@{ Id = $r.Trim(); Version = "" }
            }
        }
        return $list
    }
    if ($extDir -and (Test-Path $extDir)) {
        Get-ChildItem $extDir -Directory | ForEach-Object {
            $n = $_.Name -replace "-\d+(\.\d+)*$", ""
            [PSCustomObject]@{ Id = $n; Version = "" }
        }
    }
    return $list
}

$cursorExt = Get-IdeExtensions "cursor" (Join-Path $env:USERPROFILE ".cursor\extensions")
$codeExt   = Get-IdeExtensions "code" (Join-Path $env:USERPROFILE ".vscode\extensions")

# --- Docker images ---
$dockerImages = @()
if (Get-Command docker -ErrorAction SilentlyContinue) {
    $rows = docker images --format "{{.Repository}}:{{.Tag}} {{.ID}} {{.Size}}" 2>$null
    foreach ($r in @($rows)) {
        if ($r) { $dockerImages += $r.Trim() }
    }
}

$snapshot = [PSCustomObject]@{
    Idea = "To jest kopia srodowiska w JSON. AI i czlowiek poprawiaja ten plik (albo profil_*.json) zamiast klikac instalatory. Po wczytaniu obrazu dysku: winget upgrade --all oraz pip install -r python-requirements.txt."
    CapturedAt   = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    ComputerName = $env:COMPUTERNAME
    OS           = (Get-CimInstance Win32_OperatingSystem).Caption
    Winget       = $wingetPackages
    PythonPackages     = $pipPkgs
    PythonRequirements = "python-requirements.txt"
    NpmGlobal          = $npmPkgs
    CursorExtensions   = @($cursorExt)
    VsCodeExtensions   = @($codeExt)
    DockerImages       = $dockerImages
    HowToReplay        = @(
        "1. Przywroc obraz dysku (obraz-systemu.ps1 / Windows Backup).",
        "2. git pull tego repo (JSON = lista tego, co ma byc).",
        "3. start.bat -> zainstaluj brakujace z profil_*.json.",
        "4. winget upgrade --all",
        "5. py -m pip install -r python-requirements.txt"
    )
}

$out = Join-Path $scriptDir "srodowisko.json"
$snapshot | ConvertTo-Json -Depth 6 | Set-Content -Path $out -Encoding UTF8
Write-Host "[OK] Zapisano $out" -ForegroundColor Green
Write-Host ("Winget: {0} | pip: {1} | npm: {2} | Cursor ext: {3} | Docker: {4}" -f `
    $wingetPackages.Count, $pipPkgs.Count, $npmPkgs.Count, @($cursorExt).Count, $dockerImages.Count) -ForegroundColor Yellow
