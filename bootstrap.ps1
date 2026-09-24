<#
.SYNOPSIS
    ConsisAI - one-liner jak Chris Titus, ale sciaga CALE repo (panel + JSON + profile).

    PowerShell (Administrator), gdy repo jest publiczne:
      irm https://raw.githubusercontent.com/CONSIS-redroad/win11-workstation-setup/main/bootstrap.ps1 | iex

    Docelowo na stronie:
      irm https://www.redroad.pl/consisai | iex
    (to samo: hosting ma oddac ten plik albo przekierowac na raw GitHub).

    To NIE jest: winget https://...
    winget nie przyjmuje URL repo. Ten skrypt jest odpowiednikiem "podaj adres i dziala".
#>
$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$repo = "CONSIS-redroad/win11-workstation-setup"
$branch = "main"
$zipUrl = "https://github.com/$repo/archive/refs/heads/$branch.zip"
$root = Join-Path $env:LOCALAPPDATA "ConsisAI"
$zipPath = Join-Path $env:TEMP "consisai-setup.zip"

Write-Host "ConsisAI: pobieram paczke stanowiska (projektant + AI + kod)..." -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path $root | Out-Null
Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing

$unpack = Join-Path $env:TEMP "consisai-unpack"
if (Test-Path $unpack) { Remove-Item $unpack -Recurse -Force }
New-Item -ItemType Directory -Force -Path $unpack | Out-Null
Expand-Archive -Path $zipPath -DestinationPath $unpack -Force

$inner = Get-ChildItem $unpack -Directory | Select-Object -First 1
if (-not $inner) { throw "Puste archiwum z GitHuba. Czy repo jest publiczne?" }

Get-ChildItem $inner.FullName -Force | ForEach-Object {
    $dest = Join-Path $root $_.Name
    if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
    Move-Item $_.FullName $dest
}

$launcher = Join-Path $root "start.bat"
if (-not (Test-Path $launcher)) { throw "Brak start.bat w paczce." }

Write-Host "Uruchamiam panel ConsisAI (wybierz role: architekt / civil / programista)..." -ForegroundColor Green
Start-Process -FilePath $launcher -WorkingDirectory $root
