<#
.SYNOPSIS
    Stabilny skaner stanu systemu, tweakow rejestru i aplikacji bloatware.
#>
$ErrorActionPreference = "SilentlyContinue"
Write-Host "Rozpoczynanie pelnego audytu komputera..." -ForegroundColor Cyan

$os = Get-CimInstance Win32_OperatingSystem
$systemInfo = [PSCustomObject]@{
    ComputerName = $env:COMPUTERNAME
    OSName       = $os.Caption
    Version      = $os.Version
    BuildNumber  = $os.BuildNumber
    ScanDate     = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
}

$bloatList = @(
    "Microsoft.BingNews", "Microsoft.BingWeather", "Microsoft.BingSearch",
    "Microsoft.Copilot", "Microsoft.GamingApp", "Microsoft.XboxGamingOverlay",
    "Microsoft.XboxIdentityProvider", "Microsoft.XboxSpeechToTextOverlay",
    "Microsoft.Xbox.TCUI", "Microsoft.MicrosoftSolitaireCollection",
    "Microsoft.GetHelp", "Microsoft.WindowsFeedbackHub", "MicrosoftTeams",
    "Microsoft.OutlookForWindows"
)
$appxReport = [ordered]@{}
foreach ($b in $bloatList) {
    $found = Get-AppxPackage -Name "*$b*" -AllUsers -ErrorAction SilentlyContinue
    $appxReport[$b] = if ($found) { "Zainstalowane (Bloat)" } else { "Brak / Czysto" }
}

function Get-RegVal($path, $name, $default = $false) {
    if (Test-Path $path) {
        $item = Get-ItemProperty -Path $path -Name $name -ErrorAction SilentlyContinue
        if ($null -ne $item -and $null -ne $item.$name) {
            return $item.$name
        }
    }
    return $default
}

$tweaksReport = [PSCustomObject]@{
    DarkModeApps         = ((Get-RegVal "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "AppsUseLightTheme" 1) -eq 0)
    DarkModeSystem       = ((Get-RegVal "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "SystemUsesLightTheme" 1) -eq 0)
    LongPathsOdblokowane = ((Get-RegVal "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" "LongPathsEnabled" 0) -eq 1)
    UkrytePlikiWidoczne  = ((Get-RegVal "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Hidden" 2) -eq 1)
    RozszerzeniaWidoczne = ((Get-RegVal "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "HideFileExt" 1) -eq 0)
    BingWMenuStartOff    = ((Get-RegVal "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" "BingSearchEnabled" 1) -eq 0)
    TelemetriaWylaczona  = ((Get-RegVal "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowTelemetry" 1) -eq 0)
}

function Get-SvcStatus($name) {
    $s = Get-Service -Name $name -ErrorAction SilentlyContinue
    if ($s) { return $s.Status.ToString() }
    return "NieInstalowana"
}

$servicesReport = [PSCustomObject]@{
    XboxLiveAuth     = (Get-SvcStatus "XblAuthManager")
    XboxGameSave     = (Get-SvcStatus "XblGameSave")
    TelemetriaDiag   = (Get-SvcStatus "DiagTrack")
    ChromeRemoteHost = (Get-SvcStatus "chromoting")
}

$regPaths = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

$installedApps = Get-ItemProperty $regPaths -ErrorAction SilentlyContinue | 
    Where-Object { $_.DisplayName -and -not $_.SystemComponent } | 
    Select-Object @{N="Nazwa";E={$_.DisplayName.Trim()}}, @{N="Wersja";E={$_.DisplayVersion}}, @{N="Wydawca";E={$_.Publisher}} | 
    Sort-Object Nazwa -Unique

$finalAudit = [PSCustomObject]@{
    System           = $systemInfo
    StanTweakow      = $tweaksReport
    AplikacjeAppX    = $appxReport
    StanUslug        = $servicesReport
    ProgramyRejestr  = $installedApps
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $scriptDir) { $scriptDir = "." }
$outFile = Join-Path -Path $scriptDir -ChildPath "raport_stanu_$($env:COMPUTERNAME).json"

$finalAudit | ConvertTo-Json -Depth 5 | Set-Content -Path $outFile -Encoding UTF8
Write-Host "`n[OK] Audyt zakonczony pomyslnie!" -ForegroundColor Green
Write-Host "Wynik zapisany w: $outFile" -ForegroundColor Yellow