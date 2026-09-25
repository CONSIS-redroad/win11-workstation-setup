<#
.SYNOPSIS
    Zrzut srodowiska do JSON: winget, pip, npm, ustawienia Cursor/VS Code/Antigravity, Docker.
    Ten plik ma byc czytelny dla czlowieka i dla AI - poprawiasz JSON i masz kopie srodowiska.
    Pip + IDE: mod-zrzut-dev.ps1 (sekrety wycinane).
#>
$ErrorActionPreference = "SilentlyContinue"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $scriptDir) { $scriptDir = (Get-Location).Path }

function Refresh-Path {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
}
Refresh-Path

$mod = Join-Path $scriptDir "mod-zrzut-dev.ps1"
if (-not (Test-Path $mod)) { throw "Brak mod-zrzut-dev.ps1" }
. $mod

Write-Host "Zrzut srodowiska (winget / Python / npm / Cursor / VS Code / Antigravity / Docker)..." -ForegroundColor Cyan

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

# --- pip + Cursor / VS Code / Antigravity ---
$reqPath = Join-Path $scriptDir "python-requirements.txt"
$dev = Get-DevToolSnapshot -RequirementsPath $reqPath
$pipPkgs = @($dev.Python.packages)

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
    Python             = $dev.Python
    NpmGlobal          = $npmPkgs
    CursorExtensions   = @($dev.Cursor.extensions)
    VsCodeExtensions   = @($dev.VsCode.extensions)
    Cursor             = $dev.Cursor
    VsCode             = $dev.VsCode
    Antigravity        = $dev.Antigravity
    DockerImages       = $dockerImages
    DevSources         = $dev.Sources
    HowToReplay        = @(
        "1. Przywroc obraz dysku (obraz-systemu.ps1 / Windows Backup).",
        "2. git pull tego repo (JSON = lista tego, co ma byc).",
        "3. start.bat -> zainstaluj brakujace z profil_*.json.",
        "4. winget upgrade --all",
        "5. py -m pip install -r python-requirements.txt"
    )
}

$out = Join-Path $scriptDir "srodowisko.json"
$snapshot | ConvertTo-Json -Depth 12 | Set-Content -Path $out -Encoding UTF8
Write-Host "[OK] Zapisano $out" -ForegroundColor Green
Write-Host ("Winget: {0} | pip: {1} | npm: {2} | Cursor ext: {3} | VS Code ext: {4} | Antigravity: {5} | Docker: {6}" -f `
    $wingetPackages.Count, $pipPkgs.Count, $npmPkgs.Count, @($dev.Cursor.extensions).Count, @($dev.VsCode.extensions).Count, $dev.Antigravity.present, $dockerImages.Count) -ForegroundColor Yellow
if ($dev.Python.mcpPinWarning) {
    Write-Host ("[uwaga] {0}" -f $dev.Python.mcpPinHint) -ForegroundColor DarkYellow
}
