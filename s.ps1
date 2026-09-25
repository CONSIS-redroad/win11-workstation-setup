<#
.SYNOPSIS
    Konfigurator stanowiska Windows 11 - GUI Fluent (Stitch) + logika profili.
#>

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
if (-not $scriptDir) { $scriptDir = (Get-Location).Path }

$linkLib = Join-Path $scriptDir "link-install.ps1"
if (Test-Path $linkLib) { . $linkLib }

$xamlPath = Join-Path $scriptDir "ui.xaml"
if (-not (Test-Path $xamlPath)) {
    [System.Windows.MessageBox]::Show("Brak pliku ui.xaml obok s.ps1.", "Konfigurator") | Out-Null
    exit 1
}

[xml]$xaml = Get-Content -Path $xamlPath -Raw -Encoding UTF8
$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

function Get-Ui($name) { $window.FindName($name) }

$cmbProfiles       = Get-Ui "cmbProfiles"
$cmbRole           = Get-Ui "cmbRole"
$txtRoleBlurb      = Get-Ui "txtRoleBlurb"
$pnlAppSections    = Get-Ui "pnlAppSections"
$pnlTweakItems     = Get-Ui "pnlTweakItems"
$btnRunSelected    = Get-Ui "btnRunSelected"
$btnRunWinUtilAuto = Get-Ui "btnRunWinUtilAuto"
$btnOpenWinUtilGui = Get-Ui "btnOpenWinUtilGui"
$btnScanQuick      = Get-Ui "btnScanQuick"
$btnDumpEnv        = Get-Ui "btnDumpEnv"
$btnSystemImage    = Get-Ui "btnSystemImage"
$txtLog            = Get-Ui "txtLog"
$txtProfileName    = Get-Ui "txtProfileName"
$txtProfileDesc    = Get-Ui "txtProfileDesc"
$txtProfileFile    = Get-Ui "txtProfileFile"
$txtHwInfo         = Get-Ui "txtHwInfo"
$txtStatWinget     = Get-Ui "txtStatWinget"
$txtStatDirect     = Get-Ui "txtStatDirect"
$txtStatTweaks     = Get-Ui "txtStatTweaks"
$txtStatWinUtil    = Get-Ui "txtStatWinUtil"
$txtWingetBadge    = Get-Ui "txtWingetBadge"
$txtDirectBadge    = Get-Ui "txtDirectBadge"
$txtTweakBadge     = Get-Ui "txtTweakBadge"
$txtReadyLine      = Get-Ui "txtReadyLine"
$txtHdrSubtitle    = Get-Ui "txtHdrSubtitle"
$pageConfig        = Get-Ui "pageConfig"
$pageAudit         = Get-Ui "pageAudit"
$pageFiles         = Get-Ui "pageFiles"
$pageLink          = Get-Ui "pageLink"
$pageRun           = Get-Ui "pageRun"
$btnNavConfig      = Get-Ui "btnNavConfig"
$btnNavAudit       = Get-Ui "btnNavAudit"
$btnNavFiles       = Get-Ui "btnNavFiles"
$btnNavLink        = Get-Ui "btnNavLink"
$txtLinkUrl        = Get-Ui "txtLinkUrl"
$cmbLinkSection    = Get-Ui "cmbLinkSection"
$btnLinkResolve    = Get-Ui "btnLinkResolve"
$txtLinkStatus     = Get-Ui "txtLinkStatus"
$pnlLinkResults    = Get-Ui "pnlLinkResults"
$btnLinkSave       = Get-Ui "btnLinkSave"
$btnLinkInstall    = Get-Ui "btnLinkInstall"
$btnLinkBoth       = Get-Ui "btnLinkBoth"
$txtAuditHost      = Get-Ui "txtAuditHost"
$txtAuditOs        = Get-Ui "txtAuditOs"
$txtAuditDate      = Get-Ui "txtAuditDate"
$txtAuditSummary   = Get-Ui "txtAuditSummary"
$pnlAuditTweaks    = Get-Ui "pnlAuditTweaks"
$pnlAuditAppx      = Get-Ui "pnlAuditAppx"
$pnlAuditServices  = Get-Ui "pnlAuditServices"
$btnRunAudit       = Get-Ui "btnRunAudit"
$btnOpenAuditFile  = Get-Ui "btnOpenAuditFile"
$txtZipCmd         = Get-Ui "txtZipCmd"
$btnCopyZip        = Get-Ui "btnCopyZip"
$pnlFileList       = Get-Ui "pnlFileList"
$txtInspectorTitle = Get-Ui "txtInspectorTitle"
$txtInspectorBody  = Get-Ui "txtInspectorBody"
$btnMakeZip        = Get-Ui "btnMakeZip"
$btnOpenFolder     = Get-Ui "btnOpenFolder"
$txtRunTitle       = Get-Ui "txtRunTitle"
$txtRunStep        = Get-Ui "txtRunStep"
$barRun            = Get-Ui "barRun"
$txtRunPct         = Get-Ui "txtRunPct"
$txtRunLog         = Get-Ui "txtRunLog"
$btnBackConfig     = Get-Ui "btnBackConfig"

$brushLow    = [Windows.Media.BrushConverter]::new().ConvertFrom("#1B1C1C")
$brushHigh   = [Windows.Media.BrushConverter]::new().ConvertFrom("#2A2A2A")
$brushAccent = [Windows.Media.BrushConverter]::new().ConvertFrom("#A3C9FF")
$brushMuted  = [Windows.Media.BrushConverter]::new().ConvertFrom("#C0C7D4")
$brushOk     = [Windows.Media.BrushConverter]::new().ConvertFrom("#7ADA95")
$brushErr    = [Windows.Media.BrushConverter]::new().ConvertFrom("#FFB4AB")
$brushNavOn  = [Windows.Media.BrushConverter]::new().ConvertFrom("#2A2A2A")
$brushNavOff = [Windows.Media.Brushes]::Transparent
$brushWhite  = [Windows.Media.BrushConverter]::new().ConvertFrom("#E5E2E1")

$global:currentProfileData = $null
$global:activeControls = New-Object System.Collections.Generic.List[System.Object]
$global:sectionBadges = @{}
$global:lastAuditPath = $null
$global:currentPage = "config"
$global:linkPick = $null
$global:skipRoleChange = $false
$script:BulkChangeConfirmThreshold = 3

function Get-JsonList {
    param($Value)
    return @($Value | Where-Object { $_ })
}

function Show-UiMessage {
    param(
        [string]$Message,
        [string]$Title = "Konfigurator stanowiska",
        [System.Windows.MessageBoxButton]$Buttons = [System.Windows.MessageBoxButton]::OK,
        [System.Windows.MessageBoxImage]$Icon = [System.Windows.MessageBoxImage]::Information
    )
    return [System.Windows.MessageBox]::Show($Message, $Title, $Buttons, $Icon)
}

function Invoke-UiPump {
    try {
        [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke(
            [Action] {}, [System.Windows.Threading.DispatcherPriority]::Background)
    } catch {}
}

function Ensure-SystemRestorePoint {
    param([string]$Description = "Przed-konfiguratorem-stanowiska")
    try {
        Write-UiLog "[*] Tworzenie punktu przywracania (moze potrwac 1-2 min)..." "Cyan"
        if ($txtRunStep) { $txtRunStep.Text = "Punkt przywracania systemu..." }
        if ($txtLinkStatus) { $txtLinkStatus.Text = "Punkt przywracania (1-2 min)..." }
        Invoke-UiPump
        Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue | Out-Null
        $recent = @(Get-ComputerRestorePoint -ErrorAction SilentlyContinue |
            Sort-Object SequenceNumber -Descending |
            Select-Object -First 1)
        if ($recent.Count -gt 0 -and $recent[0].CreationTime -gt (Get-Date).AddMinutes(-10)) {
            Write-UiLog "[i] Swiezy punkt przywracania juz istnieje (ostatnie 10 min)." "Yellow"
            return $true
        }
        Invoke-UiPump
        Checkpoint-Computer -Description $Description -RestorePointType MODIFY_SETTINGS
        Write-UiLog "[OK] Punkt przywracania: $Description" "Green"
        return $true
    } catch {
        Write-UiLog "[!] Nie utworzono punktu przywracania: $_" "Red"
        $ans = Show-UiMessage -Message (
            "Nie udalo sie utworzyc punktu przywracania systemu:`n`n$_`n`n" +
            "Wlacz Przywracanie systemu dla dysku C: w ustawieniach Windows albo kontynuuj na wlasne ryzyko.") `
            -Title "Przywracanie systemu" `
            -Buttons YesNo -Icon Warning
        return ($ans -eq [System.Windows.MessageBoxResult]::Yes)
    }
}

function Confirm-ManyChanges {
    param(
        [int]$Count,
        [string[]]$Names,
        [string]$Context = "zmian w systemie"
    )
    if ($Count -lt $script:BulkChangeConfirmThreshold) { return $true }
    $list = @($Names | Select-Object -First 15)
    $preview = ($list | ForEach-Object { "  - $_" }) -join "`n"
    $extra = ""
    if ($Names.Count -gt $list.Count) {
        $extra = "`n  ... i $($Names.Count - $list.Count) dalszych pozycji"
    }
    $msg = @"
Zaznaczono $Count pozycji ($Context).

To moze trwac dlugo, wymagac restartu albo spowodowac konflikty miedzy pakietami.
Przed startem utworzymy punkt przywracania systemu (regula tego narzedzia).

$preview$extra

Kontynuowac?
"@
    $r = Show-UiMessage -Message $msg -Title "Uwaga: wiele zmian naraz" -Buttons YesNo -Icon Warning
    return ($r -eq [System.Windows.MessageBoxResult]::Yes)
}

function Apply-Role {
    param($Role)
    if (-not $Role) { return }
    if ($txtRoleBlurb) { $txtRoleBlurb.Text = [string]$Role.Blurb }
    $on = @($Role.SectionsOn)
    foreach ($ctrl in $global:activeControls) {
        if ($ctrl.Tag.Type -eq "Tweak") { continue }
        $sec = [string]$ctrl.Tag.Section
        if ($on -contains $sec) {
            $want = $true
            $data = $ctrl.Tag.Data
            if ($data -and ($data.PSObject.Properties.Name -contains "Checked")) {
                $want = [bool]$data.Checked
            }
            $ctrl.IsChecked = $want
        } else {
            $ctrl.IsChecked = $false
        }
    }
    Update-SelectionBadges
}

function Fill-RoleCombo {
    if (-not $cmbRole) { return }
    $global:skipRoleChange = $true
    $keep = [string]$cmbRole.SelectedItem
    $cmbRole.Items.Clear()
    $roles = @()
    if ($global:currentProfileData -and $global:currentProfileData.Roles) {
        $roles = Get-JsonList $global:currentProfileData.Roles
    }
    if ($txtRoleBlurb -and ($roles.Count -eq 0)) {
        $txtRoleBlurb.Text = "Ten profil nie ma rol - zaznacz pozycje recznie."
    }
    foreach ($r in $roles) {
        if (-not $r.Name) { continue }
        $cmbRole.Items.Add([string]$r.Name) | Out-Null
    }
    if ($keep -and (@($cmbRole.Items) -contains $keep)) {
        $cmbRole.SelectedItem = $keep
    } elseif ($cmbRole.Items.Count -gt 0) {
        $cmbRole.SelectedIndex = 0
    }
    $global:skipRoleChange = $false
    if ($cmbRole.SelectedItem) {
        $role = @($global:currentProfileData.Roles) | Where-Object { $_.Name -eq $cmbRole.SelectedItem } | Select-Object -First 1
        Apply-Role $role
    }
}

function Get-ProfileSections {
    param($p)
    if ($p.Sections) { return @($p.Sections) }
    return @([PSCustomObject]@{
        Id             = "legacy"
        Name           = "Pakiety"
        Description    = ""
        Winget         = $p.Winget
        DirectInstalls = $p.DirectInstalls
    })
}

function Write-UiLog {
    param([string]$Message, [string]$Color = "Gray")
    $line = "$(Get-Date -Format 'HH:mm:ss')  $Message"
    if ($txtLog) { $txtLog.AppendText("$line`r`n"); $txtLog.ScrollToEnd() }
    if ($txtRunLog) { $txtRunLog.AppendText("$line`r`n"); $txtRunLog.ScrollToEnd() }
    Write-Host $line -ForegroundColor $Color
    Invoke-UiPump
}

function Reset-Nav {
    $btnNavConfig.Background = $brushNavOff
    $btnNavAudit.Background  = $brushNavOff
    $btnNavFiles.Background  = $brushNavOff
    if ($btnNavLink) { $btnNavLink.Background = $brushNavOff; $btnNavLink.Foreground = $brushMuted }
    $btnNavConfig.Foreground = $brushMuted
    $btnNavAudit.Foreground  = $brushMuted
    $btnNavFiles.Foreground  = $brushMuted
}

function Show-Page {
    param([string]$Name)
    $global:currentPage = $Name
    $pageConfig.Visibility = "Collapsed"
    $pageAudit.Visibility  = "Collapsed"
    $pageFiles.Visibility  = "Collapsed"
    $pageRun.Visibility    = "Collapsed"
    if ($pageLink) { $pageLink.Visibility = "Collapsed" }
    Reset-Nav
    switch ($Name) {
        "config" {
            $pageConfig.Visibility = "Visible"
            $btnNavConfig.Background = $brushNavOn
            $btnNavConfig.Foreground = $brushAccent
            $txtHdrSubtitle.Text = "Konfiguracja"
        }
        "link" {
            if ($pageLink) { $pageLink.Visibility = "Visible" }
            if ($btnNavLink) {
                $btnNavLink.Background = $brushNavOn
                $btnNavLink.Foreground = $brushAccent
            }
            $txtHdrSubtitle.Text = "Z linku na winget"
            Update-LinkSections
        }
        "audit" {
            $pageAudit.Visibility = "Visible"
            $btnNavAudit.Background = $brushNavOn
            $btnNavAudit.Foreground = $brushAccent
            $txtHdrSubtitle.Text = "Audyt Systemu"
        }
        "files" {
            $pageFiles.Visibility = "Visible"
            $btnNavFiles.Background = $brushNavOn
            $btnNavFiles.Foreground = $brushAccent
            $txtHdrSubtitle.Text = "Skrypty i pliki"
            Update-FileList
        }
        "run" {
            $pageRun.Visibility = "Visible"
            $txtHdrSubtitle.Text = "Wykonywanie skryptu"
        }
    }
}

function Get-ActiveProfilePath {
    if ($cmbProfiles.SelectedItem) {
        return (Join-Path $scriptDir $cmbProfiles.SelectedItem.ToString())
    }
    return (Join-Path $scriptDir "profil_msi.json")
}

function Update-LinkSections {
    if (-not $cmbLinkSection) { return }
    $keep = [string]$cmbLinkSection.SelectedItem
    $cmbLinkSection.Items.Clear()
    $p = $global:currentProfileData
    if (-not $p) { return }
    foreach ($sec in (Get-ProfileSections $p)) {
        $cmbLinkSection.Items.Add([string]$sec.Id) | Out-Null
    }
    $ids = @($cmbLinkSection.Items)
    if ($keep -and ($ids -contains $keep)) { $cmbLinkSection.SelectedItem = $keep }
    elseif ($ids -contains "dev") { $cmbLinkSection.SelectedItem = "dev" }
    elseif ($cmbLinkSection.Items.Count -gt 0) { $cmbLinkSection.SelectedIndex = 0 }
}

function Show-LinkCandidates {
    param($resolved)
    if (-not $pnlLinkResults) { return }
    $pnlLinkResults.Children.Clear()
    $global:linkPick = $null
    if (-not $resolved.Ok) {
        $txtLinkStatus.Text = $resolved.Error
        return
    }
    $i = 0
    foreach ($c in @($resolved.Candidates)) {
        $btn = New-Object System.Windows.Controls.Button
        $btn.HorizontalContentAlignment = "Left"
        $btn.Background = $brushLow
        $btn.Foreground = $brushWhite
        $btn.BorderThickness = 0
        $btn.Margin = "0,0,0,4"
        $btn.Padding = "10"
        $btn.Cursor = "Hand"
        if ($c.Kind -eq "direct") {
            $btn.Content = "EXE/MSI  $($c.Name)"
        } else {
            $btn.Content = "$($c.Name)   [$($c.Id)]"
        }
        $pick = $c
        $btn.Add_Click({
            $global:linkPick = $pick
            $id = $pick.Id
            if (-not $id) { $id = $pick.Url }
            $txtLinkStatus.Text = "Wybrano: $($pick.Name)  $id"
        }.GetNewClosure())
        $pnlLinkResults.Children.Add($btn) | Out-Null
        if ($i -eq 0) { $global:linkPick = $c }
        $i++
    }
    $first = $global:linkPick
    $txtLinkStatus.Text = "Szukano: $($resolved.Query). Kliknij kandydata (domyslnie: $($first.Name))."
}

function Invoke-LinkResolve {
    if (-not (Get-Command Resolve-InstallLink -ErrorAction SilentlyContinue)) {
        $txtLinkStatus.Text = "Brak link-install.ps1"
        return
    }
    $txtLinkStatus.Text = "Szukam w winget..."
    [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([Action]{}, "Background")
    $resolved = Resolve-InstallLink -InputText $txtLinkUrl.Text
    Show-LinkCandidates $resolved
}

function Invoke-LinkSave {
    if (-not $global:linkPick) { $txtLinkStatus.Text = "Najpierw Szukaj i wybierz pakiet."; return }
    $pp = Get-ActiveProfilePath
    $sec = if ($cmbLinkSection.SelectedItem) { $cmbLinkSection.SelectedItem.ToString() } else { "dev" }
    try {
        $r = Add-LinkToProfile -ProfilePath $pp -SectionId $sec -Candidate $global:linkPick
        $txtLinkStatus.Text = "Zapisano do $sec ($r)."
        Write-UiLog "Profil + $($global:linkPick.Id)$($global:linkPick.Url) -> $sec" "Green"
        Update-OptionsList $pp
    } catch {
        $txtLinkStatus.Text = "Nie zapisano: $_"
    }
}

function Invoke-LinkInstallNow {
    if (-not $global:linkPick) { $txtLinkStatus.Text = "Najpierw wybierz kandydata."; return }
    $c = $global:linkPick
    Write-UiLog "[*] Punkt przywracania przed instalacja z linku..." "Cyan"
    if (-not (Ensure-SystemRestorePoint "Przed-instalacja-z-linku")) {
        $txtLinkStatus.Text = "Anulowano (brak punktu przywracania)."
        return
    }
    $txtLinkStatus.Text = "Cicha instalacja..."
    [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([Action]{}, "Background")
    try {
        if ($c.Kind -eq "direct" -or ($c.Url -and -not $c.Id)) {
            $code = Install-DirectSilent -Url $c.Url -Name $c.Name
        } else {
            $code = Install-WingetSilent -PackageId $c.Id
        }
        $txtLinkStatus.Text = "Gotowe (kod $code): $($c.Name)"
        Write-UiLog "Cicha instalacja $($c.Name) kod $code" "Green"
    } catch {
        $txtLinkStatus.Text = "Blad instalacji: $_"
        Write-UiLog "$_" "Red"
    }
}

function Update-SelectionBadges {
    $t = @($global:activeControls | Where-Object { $_.Tag.Type -eq "Tweak" })
    $tOn = @($t | Where-Object { $_.IsChecked }).Count
    $txtTweakBadge.Text = "$tOn aktywne"

    foreach ($secId in @($global:sectionBadges.Keys)) {
        $all = @($global:activeControls | Where-Object { $_.Tag.Section -eq $secId })
        $on = @($all | Where-Object { $_.IsChecked }).Count
        $global:sectionBadges[$secId].Text = "$on/$($all.Count)"
    }

    $biuro = @($global:activeControls | Where-Object { $_.Tag.Section -eq "biuro" })
    $dev   = @($global:activeControls | Where-Object { $_.Tag.Section -eq "dev" })
    if ($biuro.Count -eq 0 -and $dev.Count -eq 0) {
        $apps = @($global:activeControls | Where-Object { $_.Tag.Type -ne "Tweak" })
        $txtStatWinget.Text = "$($apps.Count) pozycji"
        $txtStatDirect.Text = "0 pozycji"
    } else {
        $txtStatWinget.Text = "$($biuro.Count) pozycji"
        $txtStatDirect.Text = "$($dev.Count) pozycji"
    }
}

function New-OptionRow {
    param($Title, $Subtitle, $Checked, $Tag)

    $border = New-Object System.Windows.Controls.Border
    $border.Background = $brushLow
    $border.CornerRadius = 8
    $border.Padding = "8"
    $border.Margin = "0,0,0,4"

    $grid = New-Object System.Windows.Controls.Grid
    $col0 = New-Object System.Windows.Controls.ColumnDefinition
    $col0.Width = [System.Windows.GridLength]::Auto
    $col1 = New-Object System.Windows.Controls.ColumnDefinition
    $col1.Width = [System.Windows.GridLength]::new(1, "Star")
    $grid.ColumnDefinitions.Add($col0) | Out-Null
    $grid.ColumnDefinitions.Add($col1) | Out-Null

    $cb = New-Object System.Windows.Controls.CheckBox
    $cb.IsChecked = [bool]$Checked
    $cb.Margin = "0,0,10,0"
    $cb.VerticalAlignment = "Center"
    $cb.Tag = $Tag
    $cb.Add_Click({ Update-SelectionBadges })

    $stack = New-Object System.Windows.Controls.StackPanel
    [System.Windows.Controls.Grid]::SetColumn($stack, 1)
    $t1 = New-Object System.Windows.Controls.TextBlock
    $t1.Text = $Title
    $t1.Foreground = $brushWhite
    $t1.FontSize = 14
    $t1.TextTrimming = "CharacterEllipsis"
    $t2 = New-Object System.Windows.Controls.TextBlock
    $t2.Text = $Subtitle
    $t2.Foreground = $brushMuted
    $t2.FontSize = 11
    $t2.TextTrimming = "CharacterEllipsis"
    $stack.Children.Add($t1) | Out-Null
    $stack.Children.Add($t2) | Out-Null

    $grid.Children.Add($cb) | Out-Null
    $grid.Children.Add($stack) | Out-Null
    $border.Child = $grid

    $global:activeControls.Add($cb)
    return $border
}

function New-SectionCard {
    param($Section, $AccentHex)

    $accent = [Windows.Media.BrushConverter]::new().ConvertFrom($AccentHex)
    $card = New-Object System.Windows.Controls.Border
    $card.Background = [Windows.Media.BrushConverter]::new().ConvertFrom("#202020")
    $card.CornerRadius = 12
    $card.Padding = "12"
    $card.Margin = "0,0,0,10"

    $root = New-Object System.Windows.Controls.StackPanel

    $head = New-Object System.Windows.Controls.DockPanel
    $head.Margin = "0,0,0,8"
    $bar = New-Object System.Windows.Controls.Border
    $bar.Width = 8
    $bar.Height = 16
    $bar.CornerRadius = 4
    $bar.Background = $accent
    $bar.Margin = "0,0,8,0"
    [System.Windows.Controls.DockPanel]::SetDock($bar, "Left")
    $badge = New-Object System.Windows.Controls.TextBlock
    $badge.FontSize = 11
    $badge.Foreground = $accent
    $badge.Padding = "8,2"
    $badge.VerticalAlignment = "Center"
    [System.Windows.Controls.DockPanel]::SetDock($badge, "Right")
    $titleBox = New-Object System.Windows.Controls.StackPanel
    $title = New-Object System.Windows.Controls.TextBlock
    $title.Text = $Section.Name
    $title.FontSize = 16
    $title.FontWeight = "SemiBold"
    $title.Foreground = $brushWhite
    $titleBox.Children.Add($title) | Out-Null
    if ($Section.Description) {
        $desc = New-Object System.Windows.Controls.TextBlock
        $desc.Text = $Section.Description
        $desc.FontSize = 11
        $desc.Foreground = $brushMuted
        $desc.TextWrapping = "Wrap"
        $titleBox.Children.Add($desc) | Out-Null
    }
    $head.Children.Add($bar) | Out-Null
    $head.Children.Add($badge) | Out-Null
    $head.Children.Add($titleBox) | Out-Null
    $root.Children.Add($head) | Out-Null

    $secId = [string]$Section.Id
    $global:sectionBadges[$secId] = $badge

    foreach ($app in (Get-JsonList $Section.Winget)) {
        $row = New-OptionRow -Title $app.Name -Subtitle $app.Id -Checked $app.Checked -Tag ([PSCustomObject]@{ Type = "Winget"; Data = $app; Section = $secId })
        $root.Children.Add($row) | Out-Null
    }
    foreach ($inst in (Get-JsonList $Section.DirectInstalls)) {
        $sub = if ($inst.LocalFile) { "Lokalny: $($inst.LocalFile)" } elseif ($inst.Url) { "URL $($inst.Args)" } else { "Brak zrodla" }
        $row = New-OptionRow -Title $inst.Name -Subtitle $sub -Checked $inst.Checked -Tag ([PSCustomObject]@{ Type = "Direct"; Data = $inst; Section = $secId })
        $root.Children.Add($row) | Out-Null
    }

    $card.Child = $root
    return $card
}

function Update-OptionsList {
    param($profilePath)

    try {
        $pnlAppSections.Children.Clear()
        $pnlTweakItems.Children.Clear()
        $global:activeControls.Clear()
        $global:sectionBadges = @{}
        $global:currentProfileData = $null

        if (-not (Test-Path $profilePath)) { return }

        $rawJson = Get-Content -Path $profilePath -Raw -Encoding UTF8
        $global:currentProfileData = $rawJson | ConvertFrom-Json

        $p = $global:currentProfileData
        $txtProfileName.Text = if ($p.ProfileName) { $p.ProfileName } else { [IO.Path]::GetFileNameWithoutExtension($profilePath) }
        $txtProfileDesc.Text = if ($p.ProfileDesc) { $p.ProfileDesc } else { "Dynamiczny profil JSON: pakiety, instalatory, tweaki" }
        $txtProfileFile.Text = [IO.Path]::GetFileName($profilePath)
        $txtStatWinUtil.Text = if ($p.WinUtilConfig) { $p.WinUtilConfig } else { "brak" }

        $accents = @("#74D1FF", "#A3C9FF", "#7ADA95", "#159CCB")
        $i = 0
        foreach ($sec in (Get-ProfileSections $p)) {
            $color = $accents[$i % $accents.Count]
            $pnlAppSections.Children.Add((New-SectionCard -Section $sec -AccentHex $color)) | Out-Null
            $i++
        }

        $tweaks = Get-JsonList $p.SystemTweaks
        $txtStatTweaks.Text = "$($tweaks.Count) tweakow"
        foreach ($tw in $tweaks) {
            $row = New-OptionRow -Title $tw.Name -Subtitle $tw.Type -Checked $tw.Checked -Tag ([PSCustomObject]@{ Type = "Tweak"; Data = $tw; Section = "tweaks" })
            $pnlTweakItems.Children.Add($row) | Out-Null
        }
        Update-SelectionBadges
        Update-LinkSections
        Fill-RoleCombo
    } catch {
        Write-UiLog "Blad ladowania profilu: $_" "Red"
        Show-UiMessage -Message "Nie udalo sie wczytac profilu:`n`n$_" -Title "Profil JSON" -Icon Error | Out-Null
    }
}

function New-StatusRow {
    param($Title, $Subtitle, $Ok, $OkText, $BadText)
    $border = New-Object System.Windows.Controls.Border
    $border.Background = $brushLow
    $border.CornerRadius = 8
    $border.Padding = "10"
    $border.Margin = "0,0,0,4"
    $grid = New-Object System.Windows.Controls.DockPanel
    $badge = New-Object System.Windows.Controls.TextBlock
    $badge.Text = if ($Ok) { $OkText } else { $BadText }
    $badge.Foreground = if ($Ok) { $brushOk } else { $brushErr }
    $badge.FontSize = 11
    $badge.VerticalAlignment = "Center"
    $badge.Margin = "8,0,0,0"
    [System.Windows.Controls.DockPanel]::SetDock($badge, "Right")
    $stack = New-Object System.Windows.Controls.StackPanel
    $t1 = New-Object System.Windows.Controls.TextBlock
    $t1.Text = $Title
    $t1.Foreground = $brushWhite
    $t2 = New-Object System.Windows.Controls.TextBlock
    $t2.Text = $Subtitle
    $t2.Foreground = $brushMuted
    $t2.FontSize = 11
    $stack.Children.Add($t1) | Out-Null
    $stack.Children.Add($t2) | Out-Null
    $grid.Children.Add($badge) | Out-Null
    $grid.Children.Add($stack) | Out-Null
    $border.Child = $grid
    return $border
}

function Invoke-AuditAndShow {
    $scanner = Join-Path $scriptDir "skanuj.ps1"
    if (-not (Test-Path $scanner)) {
        Write-UiLog "Brak skanuj.ps1" "Red"
        return
    }
    Write-UiLog "Uruchamiam audyt skanuj.ps1..." "Cyan"
    & $scanner
    $outFile = Join-Path $scriptDir "raport_stanu_$($env:COMPUTERNAME).json"
    $global:lastAuditPath = $outFile
    if (-not (Test-Path $outFile)) {
        Write-UiLog "Nie powstal plik raportu." "Red"
        return
    }
    $audit = Get-Content $outFile -Raw -Encoding UTF8 | ConvertFrom-Json
    $txtAuditHost.Text = $audit.System.ComputerName
    $txtAuditOs.Text = "$($audit.System.OSName)  Build $($audit.System.BuildNumber)"
    $txtAuditDate.Text = "Skan: $($audit.System.ScanDate) | skanuj.ps1"

    $tw = $audit.StanTweakow
    $okCount = @($tw.PSObject.Properties | Where-Object { $_.Value -eq $true }).Count
    $allTw = @($tw.PSObject.Properties).Count
    $bloat = @($audit.AplikacjeAppX.PSObject.Properties | Where-Object { $_.Value -like "Zainstalowane*" }).Count
    $txtAuditSummary.Text = "Tweaki OK: $okCount/$allTw | AppX bloat: $bloat | Raport: $(Split-Path $outFile -Leaf)"

    $pnlAuditTweaks.Children.Clear()
    $map = @(
        @{ N = "Dark Mode (aplikacje)"; K = "DarkModeApps"; Ok = "Aktywny"; Bad = "Wylaczony" },
        @{ N = "Dark Mode (system)"; K = "DarkModeSystem"; Ok = "Aktywny"; Bad = "Wylaczony" },
        @{ N = "Long Paths"; K = "LongPathsOdblokowane"; Ok = "Odblokowane"; Bad = "Limit 260" },
        @{ N = "Ukryte pliki"; K = "UkrytePlikiWidoczne"; Ok = "Widoczne"; Bad = "Ukryte" },
        @{ N = "Rozszerzenia"; K = "RozszerzeniaWidoczne"; Ok = "Widoczne"; Bad = "Ukryte" },
        @{ N = "Bing w Menu Start"; K = "BingWMenuStartOff"; Ok = "Wylaczony"; Bad = "Aktywny" },
        @{ N = "Telemetria"; K = "TelemetriaWylaczona"; Ok = "Zablokowana"; Bad = "Wlaczona" }
    )
    foreach ($m in $map) {
        $val = [bool]$tw.($m.K)
        $pnlAuditTweaks.Children.Add((New-StatusRow $m.N $m.K $val $m.Ok $m.Bad)) | Out-Null
    }

    $pnlAuditAppx.Children.Clear()
    foreach ($prop in $audit.AplikacjeAppX.PSObject.Properties) {
        $installed = $prop.Value -like "Zainstalowane*"
        $pnlAuditAppx.Children.Add((New-StatusRow $prop.Name "AppX" (-not $installed) "Czysto" "Bloat")) | Out-Null
    }

    $pnlAuditServices.Children.Clear()
    foreach ($prop in $audit.StanUslug.PSObject.Properties) {
        if ($prop.Name -eq "ChromeRemoteHost") {
            $ok = $prop.Value -eq "Running"
        } else {
            $ok = $prop.Value -match "Stopped|NieInstalowana|Disabled"
        }
        $pnlAuditServices.Children.Add((New-StatusRow $prop.Name "Usluga" $ok $prop.Value $prop.Value)) | Out-Null
    }
    Write-UiLog "Audyt zapisany: $outFile" "Green"
}

function Update-FileList {
    $pnlFileList.Children.Clear()
    $files = @(
        @{ Name = "ust_2.json"; Tag = "WinUtil"; Desc = "Lista ID Chris Titus WinUtil (instalacje, tweaki, AppX)." },
        @{ Name = "profil_consis.json"; Tag = "Consis"; Desc = "Publiczna paczka: role architekt / civil / programista. Python, 7zip, PDF, AI, BIM." },
        @{ Name = "bootstrap.ps1"; Tag = "Start"; Desc = "One-liner irm | iex. Sciaga ZIP z GitHuba i odpala panel." },
        @{ Name = "consisai.ps1"; Tag = "URL"; Desc = "Plik pod www.redroad.pl/consisai - irm https://www.redroad.pl/consisai | iex" },
        @{ Name = "srodowisko.json"; Tag = "Zrzut"; Desc = "Aktualny zrzut: winget, pip, npm, ustawienia Cursor/VS Code/Antigravity, Docker. Regeneruj zrzut-srodowiska.ps1." },
        @{ Name = "mod-zrzut-dev.ps1"; Tag = "Zrzut"; Desc = "Modul pip + settings.json Cursor/VS Code/Antigravity. Sekrety wycinane. Uzywany przez dump i scan." },
        @{ Name = "zrzut-srodowiska.ps1"; Tag = "Export"; Desc = "Zbiera biblioteki, ustawienia IDE i dodatki do srodowisko.json + python-requirements.txt." },
        @{ Name = "obraz-panel/start.bat"; Tag = "Obraz"; Desc = "Osobne menu: backup C:, wybor nosnika, pasek postepu, wersje do restore." },
        @{ Name = "obraz-systemu.ps1"; Tag = "Obraz"; Desc = "CLI backup (wbadmin) bez GUI. Runbook: OBRAZ-DYSKU.md." },
        @{ Name = "OBRAZ-DYSKU.md"; Tag = "Obraz"; Desc = "Backup i restore obrazu + co po wczytaniu. ai.bat image-check = dyski/Admin." },
        @{ Name = "skanuj.ps1"; Tag = "Audyt"; Desc = "Pre-flight: AppX, uslugi, tweaki rejestru, programy z Uninstall." },
        @{ Name = "link-install.ps1"; Tag = "Link"; Desc = "Zamiana URL ze strony na cichy winget albo EXE/MSI. Uzywane przez zakladke Z linku i ai.bat add-url." },
        @{ Name = "cli.ps1"; Tag = "AI CLI"; Desc = "JSON CLI dla agentow: test, dump, diff, compare, fill, add-winget, add-url. Wejscie: ai.bat." },
        @{ Name = "porownaj-maszyny.py"; Tag = "AI CLI"; Desc = "Porownanie zrzutow + raport.dependencyGaps (ryzyko brakujacych bibliotek)." },
        @{ Name = "aktualizuj-pip.py"; Tag = "AI CLI"; Desc = "Plan/apply pip wzgledem referencji. ai.bat pip-sync -Machine ... [-Apply]." },
        @{ Name = "maszyny/manifest.json"; Tag = "Flota"; Desc = "Moje maszyny: id, profil, plik zrzutu. ai.bat machines | compare-fleet." },
        @{ Name = "AGENTS-analityk.md"; Tag = "AI"; Desc = "Watek agenta: compare, dependencyGaps, diff — bez instalacji." },
        @{ Name = "AGENTS-instalator.md"; Tag = "AI"; Desc = "Watek agenta: fill, pip-sync, upgrade — po WhatIf/planie." },
        @{ Name = "AGENTS-audytor.md"; Tag = "AI"; Desc = "Watek agenta: test, validate, scan." },
        @{ Name = "ai.bat"; Tag = "AI CLI"; Desc = "Launcher CLI bez UAC/GUI. .\ai.bat test" },
        @{ Name = "AGENTS.md"; Tag = "AI"; Desc = "Instrukcja dla Cursor/Claude: jak testowac i uzupelniac JSON." },
        @{ Name = "ui.xaml"; Tag = "UI"; Desc = "Interfejs Fluent (Stitch) ladowany przez s.ps1." },
        @{ Name = "start.bat"; Tag = "Launcher"; Desc = "Podnosi Administratora, Bypass, Unblock-File, start s.ps1." }
    )
    foreach ($f in $files) {
        $path = Join-Path $scriptDir $f.Name
        $exists = Test-Path $path
        $size = if ($exists) { "{0:N1} KB" -f ((Get-Item $path).Length / 1KB) } else { "brak" }
        $btn = New-Object System.Windows.Controls.Button
        $btn.HorizontalContentAlignment = "Stretch"
        $btn.Background = $brushHigh
        $btn.Foreground = $brushWhite
        $btn.BorderThickness = 0
        $btn.Margin = "0,0,0,4"
        $btn.Padding = "10"
        $btn.Cursor = "Hand"
        $btn.Content = "$($f.Name)   [$($f.Tag)]   $size"
        $desc = $f.Desc
        $nm = $f.Name
        $btn.Add_Click({
            $txtInspectorTitle.Text = "Inspektor: $nm"
            $txtInspectorBody.Text = $desc
        }.GetNewClosure())
        $pnlFileList.Children.Add($btn) | Out-Null
    }
}

function Get-WinUtilConfigPath {
    if ($global:currentProfileData -and $global:currentProfileData.WinUtilConfig) {
        $cfg = Join-Path $scriptDir $global:currentProfileData.WinUtilConfig
        if (Test-Path $cfg) { return $cfg }
    }
    return $null
}

function Start-WinUtil {
    param([switch]$Run)
    if ($Run) {
        $r = Show-UiMessage -Message (
            "WinUtil (Auto -Run) zmieni ustawienia Windows (tweaki, debloat, uslugi).`n`n" +
            "Przed uruchomieniem utworzymy punkt przywracania systemu.`n`nKontynuowac?") `
            -Title "WinUtil - zmiany w systemie" -Buttons YesNo -Icon Warning
        if ($r -ne [System.Windows.MessageBoxResult]::Yes) {
            Write-UiLog "WinUtil Auto anulowany." "Yellow"
            return
        }
        Write-UiLog "[*] Punkt przywracania przed WinUtil..." "Cyan"
        if (-not (Ensure-SystemRestorePoint "Przed-WinUtil-Run")) {
            Write-UiLog "WinUtil Auto przerwany - brak punktu przywracania." "Red"
            return
        }
    }
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
    $cfg = Get-WinUtilConfigPath
    Write-UiLog "Pobieranie Chris Titus WinUtil..." "Cyan"
    if ($cfg -and $Run) {
        Invoke-Expression "& { $(Invoke-RestMethod 'https://christitus.com/win') } -Config '$cfg' -Run"
    } elseif ($cfg) {
        Invoke-Expression "& { $(Invoke-RestMethod 'https://christitus.com/win') } -Config '$cfg'"
    } elseif ($Run) {
        Invoke-Expression "& { $(Invoke-RestMethod 'https://christitus.com/win') } -Run"
    } else {
        Invoke-Expression "& { $(Invoke-RestMethod 'https://christitus.com/win') }"
    }
}

function Invoke-SelectedInstall {
    $items = @($global:activeControls | Where-Object { $_.IsChecked })
    if ($items.Count -eq 0) {
        Write-UiLog "Nic nie zaznaczono." "Yellow"
        return
    }

    $names = @($items | ForEach-Object {
        $d = $_.Tag.Data
        if ($d.Name) { [string]$d.Name } else { [string]$_.Tag.Type }
    })
    if (-not (Confirm-ManyChanges -Count $items.Count -Names $names -Context "instalacja profilu")) {
        Write-UiLog "Anulowano - uzytkownik przerwal przy wielu pozycjach." "Yellow"
        return
    }

    Show-Page "run"
    $txtRunTitle.Text = "Wykonywanie: $($txtProfileName.Text)"
    $txtRunLog.Clear()
    $n = 0
    $total = $items.Count
    $txtReadyLine.Text = "Wdrozenie w toku..."

    Write-UiLog "[*] Punkt przywracania przed instalacja profilu..." "Cyan"
    if (-not (Ensure-SystemRestorePoint "Przed-instalacja-profilu")) {
        Write-UiLog "Przerwano - brak punktu przywracania." "Red"
        $txtReadyLine.Text = "Gotowy do wdrozenia"
        Show-Page "config"
        return
    }

    foreach ($ctrl in $items) {
        $n++
        $pct = [int](($n - 1) / $total * 100)
        $barRun.Value = $pct
        $txtRunPct.Text = "$pct%"
        $item = $ctrl.Tag

            if ($item.Type -eq "Winget") {
            $txtRunStep.Text = "Winget: $($item.Data.Name)"
            Write-UiLog "[*] Winget: $($item.Data.Name)" "Yellow"
            winget install --id $item.Data.Id --exact -e --silent --accept-package-agreements --accept-source-agreements
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
            if ($item.Data.Id -in @("Git.Git","GitHub.cli")) {
                Write-UiLog "Uwaga: Git/gh w PATH dopiero w nowej konsoli (albo po odswiezeniu PATH)." "Yellow"
            }
        }
        elseif ($item.Type -eq "Direct") {
            $txtRunStep.Text = "Instalator: $($item.Data.Name)"
            Write-UiLog "[*] Pobieranie / instalacja: $($item.Data.Name)" "Yellow"
            $d = $item.Data
            $ext = ".exe"
            if ($d.LocalFile) { $ext = [IO.Path]::GetExtension($d.LocalFile) }
            elseif ($d.Url -and ($d.Url -match "\.(msi|exe)(\?|$)")) { $ext = ".$($Matches[1])" }
            $dest = Join-Path $env:TEMP ("{0}{1}" -f ($d.Name -replace "[^a-zA-Z0-9]","_"), $ext)

            if ($d.Url -and ($d.Url -match "^https?://")) {
                curl.exe -L -o $dest $d.Url
                if (Test-Path $dest) {
                    Start-Process -FilePath $dest -ArgumentList $d.Args -Wait
                } else {
                    Write-UiLog "Nie pobrano: $($d.Name)" "Red"
                }
            } elseif ($d.LocalFile) {
                $local = Join-Path $scriptDir $d.LocalFile
                if (Test-Path $local) {
                    Start-Process -FilePath $local -ArgumentList $d.Args -Wait
                } else {
                    Write-UiLog "Brak pliku lokalnego: $($d.LocalFile)" "Red"
                }
            } else {
                Write-UiLog "Brak Url i LocalFile: $($d.Name)" "Red"
            }
        }
        elseif ($item.Type -eq "Tweak") {
            $txtRunStep.Text = "Tweak: $($item.Data.Name)"
            Write-UiLog "[*] Tweak: $($item.Data.Name)" "Yellow"
            if ($item.Data.Type -eq "ThemeAndPaths") {
                Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "AppsUseLightTheme" -Value 0 -Force
                Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "SystemUsesLightTheme" -Value 0 -Force
                Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled" -Value 1 -Force
            }
            elseif ($item.Data.Type -eq "ExplorerView") {
                Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value 0 -Force
                Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Hidden" -Value 1 -Force
            }
        }
        $barRun.Value = [int]($n / $total * 100)
        $txtRunPct.Text = "$([int]($n / $total * 100))%"
    }

    $txtRunStep.Text = "Zakonczono instalacje z profilu"
    $txtReadyLine.Text = "Gotowy do wdrozenia"
    Write-UiLog "[OK] Zakonczono instalacje z profilu." "Green"
}

# Hardware line
try {
    $cpu = (Get-CimInstance Win32_Processor | Select-Object -First 1).Name
    $gpu = (Get-CimInstance Win32_VideoController | Select-Object -First 1).Name
    $txtHwInfo.Text = "$env:COMPUTERNAME | $cpu"
} catch {
    $txtHwInfo.Text = $env:COMPUTERNAME
}

$txtReadyLine.Text = "Gotowy do wdrozenia (PowerShell $($PSVersionTable.PSVersion))"
$zipCmd = 'Compress-Archive -Path "ust_2.json","profil_msi.json","skanuj.ps1","s.ps1","start.bat","ui.xaml" -DestinationPath ".\Pakiet_Konfiguracyjny.zip" -Force'
$txtZipCmd.Text = $zipCmd

$profiles = @(Get-ChildItem -Path $scriptDir -Filter "profil_*.json")
foreach ($p in $profiles) {
    $cmbProfiles.Items.Add($p.Name) | Out-Null
}

$cmbProfiles.Add_SelectionChanged({
    if ($cmbProfiles.SelectedItem) {
        $chosen = Join-Path $scriptDir $cmbProfiles.SelectedItem.ToString()
        try { Update-OptionsList $chosen } catch { Write-UiLog "Blad profilu: $_" "Red" }
    }
})

if ($cmbRole) {
    $cmbRole.Add_SelectionChanged({
        if ($global:skipRoleChange) { return }
        if (-not $cmbRole.SelectedItem) { return }
        if (-not ($global:currentProfileData -and $global:currentProfileData.Roles)) { return }
        $role = @($global:currentProfileData.Roles) | Where-Object { $_.Name -eq $cmbRole.SelectedItem } | Select-Object -First 1
        Apply-Role $role
    })
}

if ($profiles.Count -gt 0) {
    $prefer = "profil_consis.json"
    $idx = 0
    for ($i = 0; $i -lt $cmbProfiles.Items.Count; $i++) {
        if ($cmbProfiles.Items[$i].ToString() -eq $prefer) { $idx = $i; break }
    }
    try { $cmbProfiles.SelectedIndex = $idx } catch { Write-UiLog "Blad startu profilu: $_" "Red" }
}

$btnNavConfig.Add_Click({ Show-Page "config" })
$btnNavAudit.Add_Click({ Show-Page "audit" })
$btnNavFiles.Add_Click({ Show-Page "files" })
if ($btnNavLink) { $btnNavLink.Add_Click({ Show-Page "link" }) }
$btnBackConfig.Add_Click({ Show-Page "config" })
if ($btnLinkResolve) { $btnLinkResolve.Add_Click({ Invoke-LinkResolve }) }
if ($btnLinkSave) { $btnLinkSave.Add_Click({ Invoke-LinkSave }) }
if ($btnLinkInstall) { $btnLinkInstall.Add_Click({ Invoke-LinkInstallNow }) }
if ($btnLinkBoth) {
    $btnLinkBoth.Add_Click({ Invoke-LinkSave; Invoke-LinkInstallNow })
}

$btnRunSelected.Add_Click({ Invoke-SelectedInstall })
$btnRunWinUtilAuto.Add_Click({ Start-WinUtil -Run })
$btnOpenWinUtilGui.Add_Click({ Start-WinUtil })
$btnScanQuick.Add_Click({ Show-Page "audit"; Invoke-AuditAndShow })
if ($btnDumpEnv) {
    $btnDumpEnv.Add_Click({
        $f = Join-Path $scriptDir "zrzut-srodowiska.ps1"
        if (-not (Test-Path $f)) { Write-UiLog "Brak zrzut-srodowiska.ps1" "Red"; return }
        Write-UiLog "Zrzut srodowiska (winget, pip, dodatki AI)..." "Cyan"
        & $f
        $snap = Join-Path $scriptDir "srodowisko.json"
        if (Test-Path $snap) { Write-UiLog "Zapisano srodowisko.json - to kopia srodowiska do gita i dla AI." "Green" }
        else { Write-UiLog "Zrzut nie zapisal srodowisko.json" "Yellow" }
    })
}
if ($btnSystemImage) {
    $btnSystemImage.Add_Click({
        $bat = Join-Path $scriptDir "obraz-panel\start.bat"
        if (Test-Path $bat) {
            Write-UiLog "Otwieram panel obrazu dysku (backup / przywracanie)." "Cyan"
            Start-Process $bat
            return
        }
        $f = Join-Path $scriptDir "obraz-systemu.ps1"
        if (-not (Test-Path $f)) { Write-UiLog "Brak obraz-panel i obraz-systemu.ps1" "Red"; return }
        Write-UiLog "Otwieram obraz-systemu.ps1 (CLI)." "Cyan"
        Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$f`""
    })
}
$btnRunAudit.Add_Click({ Invoke-AuditAndShow })
$btnOpenAuditFile.Add_Click({
    if ($global:lastAuditPath -and (Test-Path $global:lastAuditPath)) {
        Start-Process $global:lastAuditPath
    } else {
        $guess = Join-Path $scriptDir "raport_stanu_$($env:COMPUTERNAME).json"
        if (Test-Path $guess) { Start-Process $guess } else { Write-UiLog "Najpierw wygeneruj raport." "Yellow" }
    }
})
$btnCopyZip.Add_Click({
    Set-Clipboard -Value $txtZipCmd.Text
    Write-UiLog "Skopiowano polecenie Compress-Archive." "Green"
})
$btnMakeZip.Add_Click({
    $dest = Join-Path $scriptDir "Pakiet_Konfiguracyjny.zip"
    $paths = @("ust_2.json","profil_msi.json","skanuj.ps1","s.ps1","start.bat","ui.xaml","zrzut-srodowiska.ps1","obraz-systemu.ps1","README.md") | ForEach-Object { Join-Path $scriptDir $_ } | Where-Object { Test-Path $_ }
    Compress-Archive -Path $paths -DestinationPath $dest -Force
    Write-UiLog "Zapisano $dest" "Green"
})
$btnOpenFolder.Add_Click({ Start-Process explorer.exe $scriptDir })

Show-Page "config"
Write-UiLog "Panel gotowy. Profile: $($profiles.Count)." "Cyan"

$app = [System.Windows.Application]::Current
if (-not $app) { $app = New-Object System.Windows.Application }
$app.ShutdownMode = [System.Windows.ShutdownMode]::OnMainWindowClose
$app.add_DispatcherUnhandledException({
    param($sender, $e)
    $msg = [string]$e.Exception.Message
    try { Write-UiLog "BLAD GUI: $msg" "Red" } catch {}
    try { Show-UiMessage -Message "Blad GUI (okno zostaje otwarte):`n`n$msg" -Title "Konfigurator stanowiska" -Icon Error | Out-Null } catch {}
    $e.Handled = $true
})

try {
    [void]$window.ShowDialog()
} catch {
    Show-UiMessage -Message "Okno padlo przy starcie:`n`n$_" -Title "Konfigurator stanowiska" -Icon Error | Out-Null
}
