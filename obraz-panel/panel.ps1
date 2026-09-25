# Obraz dysku — osobny panel (backup / przywracanie)
$ErrorActionPreference = "Stop"

if ([System.Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') {
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Sta -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Sta -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = Split-Path -Parent $scriptDir
. (Join-Path $scriptDir "obraz-wbadmin.ps1")

$xamlPath = Join-Path $scriptDir "ui.xaml"
[xml]$xaml = Get-Content -Path $xamlPath -Raw -Encoding UTF8
$window = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xaml))

function Get-Ui($n) { $window.FindName($n) }

$cmbBackupTarget  = Get-Ui "cmbBackupTarget"
$cmbRestoreSource = Get-Ui "cmbRestoreSource"
$txtBackupSpace   = Get-Ui "txtBackupSpace"
$txtCEstimate     = Get-Ui "txtCEstimate"
$chkRestorePoint  = Get-Ui "chkRestorePoint"
$chkConfirmBackup = Get-Ui "chkConfirmBackup"
$btnRefreshVolumes= Get-Ui "btnRefreshVolumes"
$btnStartBackup   = Get-Ui "btnStartBackup"
$barBackup        = Get-Ui "barBackup"
$txtBackupPct     = Get-Ui "txtBackupPct"
$txtBackupStatus  = Get-Ui "txtBackupStatus"
$btnLoadVersions  = Get-Ui "btnLoadVersions"
$lstVersions      = Get-Ui "lstVersions"
$txtRecoveryCmd   = Get-Ui "txtRecoveryCmd"
$btnCopyRecovery  = Get-Ui "btnCopyRecovery"
$btnOpenRecovery  = Get-Ui "btnOpenRecovery"
$btnOpenDocs      = Get-Ui "btnOpenDocs"
$btnOpenMainPanel = Get-Ui "btnOpenMainPanel"
$txtSubtitle      = Get-Ui "txtSubtitle"

$global:backupProc = $null
$global:backupTargetLetter = $null
$global:backupEstimateBytes = 0
$global:progressTimer = $null

function Update-BackupButtonState {
    $ok = $false
    if ($cmbBackupTarget.SelectedItem -and $chkConfirmBackup.IsChecked) {
        $v = $cmbBackupTarget.SelectedItem
        if ($v.OkTarget -and $v.FreeGb -ge 20) { $ok = $true }
    }
    $btnStartBackup.IsEnabled = $ok -and (-not $global:backupProc)
}

function Refresh-VolumeLists {
    $vols = Get-ObrazVolumes
    $items = @()
    foreach ($v in $vols) {
        $fs = if ($v.OkTarget) { $v.FileSystem } else { "$($v.FileSystem) !" }
        $items += [PSCustomObject]@{
            Letter  = $v.Letter
            Display = "$($v.Letter):  $($v.Label)  -  wolne $($v.FreeGb) GB / $($v.TotalGb) GB  ($fs)"
            FreeGb  = $v.FreeGb
            OkTarget = $v.OkTarget
        }
    }
    $cmbBackupTarget.ItemsSource = $items
    $cmbRestoreSource.ItemsSource = $items
    if ($items.Count -gt 0) {
        $cmbBackupTarget.SelectedIndex = 0
        $cmbRestoreSource.SelectedIndex = 0
    }
    $used = Get-CSystemUsedBytes
    $need = Get-SuggestedBackupGb $used
    $txtCEstimate.Text = "Zajetosc C: ~$([math]::Round($used/1GB,1)) GB. Zalecane wolne na nosniku: okolo $need GB."
    Update-BackupTargetHint
}

function Update-BackupTargetHint {
    if (-not $cmbBackupTarget.SelectedItem) {
        $txtBackupSpace.Text = "Podlacz dysk USB/SSD (NTFS)."
        return
    }
    $v = $cmbBackupTarget.SelectedItem
    $need = Get-SuggestedBackupGb (Get-CSystemUsedBytes)
    if (-not $v.OkTarget) {
        $txtBackupSpace.Text = "Ten wolumin moze nie byc obslugiwany przez wbadmin (preferuj NTFS)."
        return
    }
    if ($v.FreeGb -lt $need) {
        $txtBackupSpace.Text = "Mal miejsca: wolne $($v.FreeGb) GB, zalecane ~$need GB."
    } else {
        $txtBackupSpace.Text = "OK: $($v.Letter): ma $($v.FreeGb) GB wolne (zalecane ~$need GB)."
    }
}

function Set-BackupProgress {
    param([int]$Pct, [string]$Status, [string]$PctLabel)
    $barBackup.Value = [math]::Min(100, [math]::Max(0, $Pct))
    if ($PctLabel) { $txtBackupPct.Text = $PctLabel }
    if ($Status) { $txtBackupStatus.Text = $Status }
    [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([Action]{}, "Background")
}

function Stop-ProgressTimer {
    if ($global:progressTimer) {
        $global:progressTimer.Stop()
        $global:progressTimer = $null
    }
}

function Start-ProgressTimer {
    Stop-ProgressTimer
    $global:progressTimer = New-Object System.Windows.Threading.DispatcherTimer
    $global:progressTimer.Interval = [TimeSpan]::FromSeconds(2)
    $global:progressTimer.Add_Tick({
        if (-not $global:backupProc) { return }
        if ($global:backupProc.HasExited) {
            Stop-ProgressTimer
            $code = $global:backupProc.ExitCode
            $letter = $global:backupTargetLetter
            $global:backupProc = $null
            if ($code -eq 0) {
                Set-BackupProgress -Pct 100 -PctLabel "100%" -Status "Backup zakonczony pomyslnie na ${letter}:"
                [System.Windows.MessageBox]::Show("Obraz zapisany na ${letter}:.", "OK") | Out-Null
            } else {
                Set-BackupProgress -Pct 0 -PctLabel "Blad" -Status "wbadmin kod $code. Sprawdz NTFS i Windows Backup."
            }
            Update-BackupButtonState
            return
        }
        $size = Get-BackupFolderSize -Letter $global:backupTargetLetter
        $est = $global:backupEstimateBytes
        if ($est -gt 0) {
            $pct = [int][math]::Min(99, ($size / $est) * 100)
            $gb = [math]::Round($size / 1GB, 2)
            Set-BackupProgress -Pct $pct -PctLabel "$pct%" -Status "Zapisano ok. $gb GB w WindowsImageBackup..."
        } else {
            Set-BackupProgress -Pct 50 -PctLabel "..." -Status "Backup w toku (wbadmin)..."
        }
    })
    $global:progressTimer.Start()
}

$btnRefreshVolumes.Add_Click({ Refresh-VolumeLists })
$cmbBackupTarget.Add_SelectionChanged({ Update-BackupTargetHint; Update-BackupButtonState })
$chkConfirmBackup.Add_Checked({ Update-BackupButtonState })
$chkConfirmBackup.Add_Unchecked({ Update-BackupButtonState })

$btnStartBackup.Add_Click({
    if (-not $cmbBackupTarget.SelectedItem) { return }
    $letter = [string]$cmbBackupTarget.SelectedItem.Letter
    if ($letter -eq 'C') {
        [System.Windows.MessageBox]::Show("Nie mozna zapisac obrazu na C:.", "Obraz dysku") | Out-Null
        return
    }
    $ans = [System.Windows.MessageBox]::Show(
        "Rozpoczac backup C: na ${letter}:?`n`nMoze to potrwac. Nie wylaczaj komputera.",
        "Potwierdzenie", "YesNo", "Warning")
    if ($ans -ne "Yes") { return }

    if ($chkRestorePoint.IsChecked) {
        $cp = Invoke-ObrazCheckpoint
        Set-BackupProgress -Pct 0 -PctLabel "0%" -Status $cp.message
    }

    $global:backupTargetLetter = $letter
    $global:backupEstimateBytes = [long](Get-CSystemUsedBytes * 1.15)
    Set-BackupProgress -Pct 2 -PctLabel "2%" -Status "Start wbadmin..."
    $btnStartBackup.IsEnabled = $false

    try {
        $global:backupProc = Start-ObrazBackup -Letter $letter
        Start-ProgressTimer
        Set-BackupProgress -Pct 3 -PctLabel "..." -Status "wbadmin w toku (pasek szacunkowy po rozmiarze folderu)."
    } catch {
        Stop-ProgressTimer
        $global:backupProc = $null
        Set-BackupProgress -Pct 0 -PctLabel "Blad" -Status "$_"
        Update-BackupButtonState
    }
})

$btnLoadVersions.Add_Click({
    if (-not $cmbRestoreSource.SelectedItem) { return }
    $letter = [string]$cmbRestoreSource.SelectedItem.Letter
    $res = Get-WbadminVersions -Letter $letter
    if (-not $res.ok) {
        $lstVersions.ItemsSource = @([PSCustomObject]@{ Display = $res.error })
        $txtRecoveryCmd.Text = ""
        return
    }
    $list = @()
    foreach ($v in $res.versions) {
        $id = if ($v.VersionId) { $v.VersionId } else { $v.Time }
        $list += [PSCustomObject]@{ Display = $id; VersionId = $id; Letter = $letter }
    }
    if ($list.Count -eq 0) {
        $list = @([PSCustomObject]@{ Display = "Brak wersji - najpierw zrob backup na tym nosniku."; VersionId = ""; Letter = $letter })
    }
    $lstVersions.ItemsSource = $list
    $lstVersions.SelectedIndex = 0
})

$lstVersions.Add_SelectionChanged({
    $sel = $lstVersions.SelectedItem
    if (-not $sel -or -not $sel.VersionId) {
        $txtRecoveryCmd.Text = ""
        return
    }
    $letter = $sel.Letter
    $ver = $sel.VersionId
    $txtRecoveryCmd.Text = "wbadmin start recovery -version:$ver -backupTarget:${letter}: -recoveryTarget:C:"
})

$btnCopyRecovery.Add_Click({
    if ($txtRecoveryCmd.Text) {
        Set-Clipboard -Value $txtRecoveryCmd.Text
        $txtSubtitle.Text = "Skopiowano komende do schowka."
    }
})

$btnOpenRecovery.Add_Click({ Open-WindowsRecoveryHelp })

$btnOpenDocs.Add_Click({
    $doc = Join-Path $rootDir "OBRAZ-DYSKU.md"
    if (Test-Path $doc) { Start-Process $doc } else {
        [System.Windows.MessageBox]::Show("Brak OBRAZ-DYSKU.md w katalogu nadrzednym.", "Obraz") | Out-Null
    }
})

$btnOpenMainPanel.Add_Click({
    $bat = Join-Path $rootDir "start.bat"
    if (Test-Path $bat) { Start-Process $bat }
})

$txtSubtitle.Text = "$($env:COMPUTERNAME) · Administrator · wbadmin"
Refresh-VolumeLists
Update-BackupButtonState

$window.ShowDialog() | Out-Null
