$ErrorActionPreference = 'Stop'
$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$errs = @()
$null = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $dir 'panel.ps1'), [ref]$null, [ref]$errs)
if ($errs.Count -gt 0) { throw "panel.ps1 parse: $($errs | Out-String)" }
$errs2 = @()
$null = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $dir 'obraz-wbadmin.ps1'), [ref]$null, [ref]$errs2)
if ($errs2.Count -gt 0) { throw "obraz-wbadmin.ps1 parse: $($errs2 | Out-String)" }

. (Join-Path $dir 'obraz-wbadmin.ps1')
$vols = @(Get-ObrazVolumes)
if ($vols.Count -lt 1) { throw 'Brak woluminow backup (oczekiwano >=1 poza C)' }

Add-Type -AssemblyName PresentationFramework
[xml]$xaml = Get-Content (Join-Path $dir 'ui.xaml') -Raw -Encoding UTF8
$reader = New-Object System.Xml.XmlNodeReader $xaml
$win = [Windows.Markup.XamlReader]::Load($reader)
$names = @('cmbBackupTarget','btnStartBackup','barBackup','lstVersions')
foreach ($n in $names) {
    if (-not $win.FindName($n)) { throw "Brak elementu UI: $n" }
}

@{
    ok = $true
    parse = 'ok'
    xaml = $win.Title
    volumes = $vols.Count
    sampleVolume = $vols[0].Letter
} | ConvertTo-Json
