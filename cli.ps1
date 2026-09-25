# AI CLI - konfigurator stanowiska
#
# Odpalaj z katalogu pakietu (bez GUI, JSON na stdout):
#   .\ai.bat help
#   .\ai.bat test
#   .\ai.bat status
#   .\ai.bat dump
#   .\ai.bat diff
#   .\ai.bat fill -Section dev
#   .\ai.bat add-winget -Section ai-cli -Id Anthropic.ClaudeCode -Name "Claude Code"
#
# Caly stdout = JSON. Kod wyjscia: 0 OK, 1 blad danych/plikow, 2 brak narzedzia.
# Nie odpalac start.bat / s.ps1 z agenta.

param(
    [Parameter(Position = 0)]
    [string]$Command = "help",

    [string]$Profile = "profil_msi.json",
    [string]$Section = "dev",
    [string]$Id = "",
    [string]$Name = "",
    [string]$Url = "",
    [string]$Other = "",
    [string]$Machine = "",
    [string]$OtherMachine = "",
    [switch]$Install,
    [switch]$WhatIf,
    [switch]$Apply,
    [switch]$ConfirmApply,
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $scriptDir) { $scriptDir = (Get-Location).Path }
Set-Location $scriptDir

$linkLib = Join-Path $scriptDir "link-install.ps1"
if (Test-Path $linkLib) { . $linkLib }

$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

function Emit {
    param($Object)
    $Object | ConvertTo-Json -Depth 10
}

function Fail {
    param([string]$Message, [int]$Code = 1)
    Emit @{ ok = $false; error = $Message }
    exit $Code
}

function Get-ProfilePath {
    $p = Join-Path $scriptDir $Profile
    if (-not (Test-Path $p)) { Fail "Brak profilu: $Profile" }
    return $p
}

function Read-Profile {
    return (Get-Content -Path (Get-ProfilePath) -Raw -Encoding UTF8 | ConvertFrom-Json)
}

function Save-Profile {
    param($Data)
    $json = $Data | ConvertTo-Json -Depth 12
    Set-Content -Path (Get-ProfilePath) -Value $json -Encoding UTF8
}

function Get-Section {
    param($Data, [string]$SecId)
    $sec = @($Data.Sections) | Where-Object { $_.Id -eq $SecId } | Select-Object -First 1
    if (-not $sec) { Fail "Brak sekcji '$SecId' w $Profile" }
    return $sec
}

function Get-Tool {
    param([string]$Exe, [string]$VersionArg = "--version")
    $cmd = Get-Command $Exe -ErrorAction SilentlyContinue
    if (-not $cmd) {
        return [PSCustomObject]@{ name = $Exe; found = $false; path = $null; version = $null }
    }
    $ver = $null
    try {
        $ver = (& $Exe $VersionArg 2>$null | Select-Object -First 1)
        if ($ver) { $ver = $ver.ToString().Trim() }
    } catch {}
    return [PSCustomObject]@{ name = $Exe; found = $true; path = $cmd.Source; version = $ver }
}

function Get-ProfileIds {
    param($Data)
    $ids = New-Object System.Collections.Generic.List[string]
    foreach ($sec in @($Data.Sections)) {
        foreach ($app in @($sec.Winget)) { if ($app.Id) { $ids.Add([string]$app.Id) } }
    }
    foreach ($app in @($Data.Winget)) { if ($app.Id) { $ids.Add([string]$app.Id) } }
    return $ids
}

function Invoke-Help {
    Emit @{
        ok = $true
        cli = "ai.bat / cli.ps1"
        idea = "JSON-first. AI testuje i uzupelnia dane bez GUI."
        commands = @(
            @{ cmd = "help";      use = "ta pomoc (JSON)" }
            @{ cmd = "test";      use = "szybki test: pliki, JSON, git/gh/python/node/docker + claude/cursor/gitleaks" }
            @{ cmd = "status";    use = "narzedzia + czy sa zrzuty" }
            @{ cmd = "dump";      use = "zrzut: winget, pip, ustawienia Cursor/VS Code/Antigravity -> srodowisko.json" }
            @{ cmd = "scan";      use = "audyt tweakow -> raport_stanu_<PC>.json" }
            @{ cmd = "profile";   use = "wypisz profil JSON" }
            @{ cmd = "list";      use = "lista pakietow z profilu" }
            @{ cmd = "diff";      use = "winget zrzut vs profil (czego brakuje w przepisie)" }
            @{ cmd = "machines";  use = "lista moich maszyn (maszyny/manifest.json)" }
            @{ cmd = "compare";   use = "porownaj zrzuty (py): -Machine id | -Other plik | -OtherMachine id" }
            @{ cmd = "compare-fleet"; use = "porownaj kazda pare z manifestu (liczby + ryzyka)" }
            @{ cmd = "pip-sync";    use = "plan pip vs referencja (-Machine id); -Apply wykonuje pip install" }
            @{ cmd = "fill";       use = "dopisz brakujace ID winget do sekcji (-Section, domyslnie dev)" }
            @{ cmd = "add-winget"; use = "dopisz jedno ID: -Section ... -Id Vendor.Package [-Name ...]" }
            @{ cmd = "add-url";    use = "link ze strony -> winget: -Url https://...  [-Section dev] [-Install]" }
            @{ cmd = "validate";  use = "sprawdz JSON-y (oba profile + ust_2.json)" }
            @{ cmd = "upgrade";   use = "winget upgrade --all (wymaga sieci)" }
            @{ cmd = "image";     use = "runbook obrazu dysku (backup/restore) jako JSON" }
            @{ cmd = "image-check"; use = "woluminy, Admin, wbadmin get versions (jesli Admin)" }
        )
        flags = @(
            @{ flag = "-Profile"; use = "plik przepisu (domyslnie profil_msi.json)" }
            @{ flag = "-Section"; use = "sekcja fill/add-winget/add-url (domyslnie dev)" }
            @{ flag = "-Id";      use = "ID winget dla add-winget" }
            @{ flag = "-Name";    use = "czytelna nazwa dla add-winget" }
            @{ flag = "-Url";     use = "strona lub bezposredni .exe/.msi dla add-url" }
            @{ flag = "-Install"; use = "add-url: zainstaluj po dopisaniu" }
            @{ flag = "-WhatIf";  use = "fill / add-winget / add-url / upgrade: bez zapisu i bez instalacji" }
            @{ flag = "-Other";   use = "compare: drugi plik srodowisko.json" }
            @{ flag = "-Machine"; use = "compare: id z manifestu (lewy = lokalny srodowisko.json jesli brak -OtherMachine)" }
            @{ flag = "-OtherMachine"; use = "compare: drugi id z manifestu (bez lokalnego zrzutu)" }
            @{ flag = "-Apply"; use = "pip-sync: wymaga tez -ConfirmApply (globalny pip)" }
            @{ flag = "-ConfirmApply"; use = "pip-sync: drugie potwierdzenie Apply" }
            @{ flag = "-Force"; use = "pip-sync Apply: wiecej niz 25 pakietow" }
        )
        exitCodes = @{ "0" = "ok"; "1" = "blad danych/plikow"; "2" = "brak narzedzia" }
        never = @("start.bat", "s.ps1")
        examples = @(
            ".\ai.bat test",
            ".\ai.bat status",
            ".\ai.bat dump",
            ".\ai.bat diff",
            ".\ai.bat fill -Section ai-cli -WhatIf",
            '.\ai.bat add-winget -Section ai-cli -Id Anthropic.ClaudeCode -Name "Claude Code"',
            ".\ai.bat add-url -Url https://git-scm.com -Section dev -WhatIf",
            ".\ai.bat validate -Profile profil_consis.json",
            ".\ai.bat machines",
            ".\ai.bat compare -Machine msi",
            ".\ai.bat compare -Machine msi -OtherMachine consis-b2bgdma",
            ".\ai.bat compare-fleet",
            ".\ai.bat pip-sync -Machine consis-b2bgdma",
            ".\ai.bat image",
            ".\ai.bat image-check",
            "py porownaj-maszyny.py maszyny/msi.json maszyny/consis-b2bgdma.json"
        )
    }
}

function Invoke-Validate {
    $problems = @()
    $files = @("profil_msi.json", "profil_consis.json", "ust_2.json")
    foreach ($f in $files) {
        $path = Join-Path $scriptDir $f
        if (-not (Test-Path $path)) { $problems += "brak $f"; continue }
        try { $null = Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json }
        catch { $problems += ('{0}: {1}' -f $f, $_) }
    }
    $prof = $null
    try { $prof = Read-Profile } catch { $problems += "profil: $_" }
    $sectionIds = @()
    if ($prof) { $sectionIds = @($prof.Sections | ForEach-Object { $_.Id }) }
    $ok = ($problems.Count -eq 0)
    Emit @{
        ok = $ok
        profile = $Profile
        sections = $sectionIds
        problems = $problems
    }
    if (-not $ok) { exit 1 }
}

function Invoke-Status {
    $tools = @(
        (Get-Tool "git"),
        (Get-Tool "gh"),
        (Get-Tool "python"),
        (Get-Tool "py"),
        (Get-Tool "node"),
        (Get-Tool "npm"),
        (Get-Tool "docker"),
        (Get-Tool "cursor"),
        (Get-Tool "code"),
        (Get-Tool "claude"),
        (Get-Tool "gitleaks"),
        (Get-Tool "winget")
    )
    Emit @{
        ok = $true
        computer = $env:COMPUTERNAME
        cwd = $scriptDir
        profile = $Profile
        tools = $tools
        files = @{
            srodowisko     = (Test-Path (Join-Path $scriptDir "srodowisko.json"))
            pythonReq      = (Test-Path (Join-Path $scriptDir "python-requirements.txt"))
            wingetExport   = (Test-Path (Join-Path $scriptDir "winget-export.json"))
            profil         = (Test-Path (Get-ProfilePath))
        }
    }
}

function Invoke-Test {
    $toolsWanted = @("winget", "git", "gh", "python", "node", "docker")
    $missing = @()
    $present = @()
    foreach ($n in $toolsWanted) {
        $t = Get-Tool $n
        if ($t.found) { $present += $t } else { $missing += $n }
    }
    $ai = @("claude", "cursor", "gitleaks") | ForEach-Object { Get-Tool $_ }
    $problems = @()
    foreach ($f in @("profil_msi.json", "cli.ps1", "zrzut-srodowiska.ps1", "mod-zrzut-dev.ps1")) {
        if (-not (Test-Path (Join-Path $scriptDir $f))) { $problems += "brak $f" }
    }
    try { $null = Read-Profile } catch { $problems += "profil JSON: $_" }
    $ok = ($problems.Count -eq 0)
    Emit @{
        ok = $ok
        readyForAi = $ok
        hint = "Brakujace narzedzia doinstaluj z profilu (sekcja dev / ai-cli), potem: ai.bat dump && ai.bat fill"
        problems = $problems
        present = $present
        missingCore = $missing
        aiCli = $ai
    }
    if (-not $ok) { exit 1 }
}

function Invoke-Dump {
    $z = Join-Path $scriptDir "zrzut-srodowiska.ps1"
    if (-not (Test-Path $z)) { Fail "brak zrzut-srodowiska.ps1" }
    & $z | Out-Null
    $snap = Join-Path $scriptDir "srodowisko.json"
    if (-not (Test-Path $snap)) { Fail "dump nie zapisal srodowisko.json" }
    $data = Get-Content $snap -Raw -Encoding UTF8 | ConvertFrom-Json
    Emit @{
        ok = $true
        path = $snap
        winget = @($data.Winget).Count
        pip = @($data.PythonPackages).Count
        npm = @($data.NpmGlobal).Count
        cursorExt = @($data.CursorExtensions).Count
        vscodeExt = @($data.VsCodeExtensions).Count
        cursorSettings = [bool]$data.Cursor.settingsExists
        vscodeSettings = [bool]$data.VsCode.settingsExists
        antigravity = [bool]$data.Antigravity.present
        mcpPinWarning = [bool]$data.Python.mcpPinWarning
        docker = @($data.DockerImages).Count
    }
}

function Invoke-Scan {
    $s = Join-Path $scriptDir "skanuj.ps1"
    if (-not (Test-Path $s)) { Fail "brak skanuj.ps1" }
    & $s | Out-Null
    $out = Join-Path $scriptDir "raport_stanu_$($env:COMPUTERNAME).json"
    Emit @{ ok = (Test-Path $out); path = $out }
}

function Invoke-ProfileShow {
    Read-Profile | ConvertTo-Json -Depth 12
}

function Invoke-List {
    $p = Read-Profile
    $rows = @()
    foreach ($sec in @($p.Sections)) {
        foreach ($app in @($sec.Winget)) {
            $rows += [PSCustomObject]@{ section = $sec.Id; type = "winget"; name = $app.Name; id = $app.Id; checked = [bool]$app.Checked }
        }
        foreach ($inst in @($sec.DirectInstalls)) {
            if (-not $inst) { continue }
            if (-not $inst.Name -and -not $inst.LocalFile -and -not $inst.Url) { continue }
            $rows += [PSCustomObject]@{ section = $sec.Id; type = "direct"; name = $inst.Name; id = $inst.LocalFile; checked = [bool]$inst.Checked }
        }
    }
    Emit @{ ok = $true; profile = $Profile; items = $rows }
}

function Get-DumpWingetIds {
    $snap = Join-Path $scriptDir "srodowisko.json"
    if (-not (Test-Path $snap)) { return @() }
    $data = Get-Content $snap -Raw -Encoding UTF8 | ConvertFrom-Json
    return @($data.Winget | ForEach-Object { $_.Id } | Where-Object { $_ })
}

function Get-MachinesManifest {
    $path = Join-Path $scriptDir "maszyny\manifest.json"
    if (-not (Test-Path $path)) { Fail "brak maszyny/manifest.json" }
    return (Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json)
}

function Get-MachineEntry {
    param([string]$MachineId)
    if (-not $MachineId) { return $null }
    $manifest = Get-MachinesManifest
    $entry = @($manifest.Machines) | Where-Object { $_.id -eq $MachineId } | Select-Object -First 1
    if (-not $entry) {
        $ids = (@($manifest.Machines) | ForEach-Object { $_.id }) -join ", "
        Fail "Nieznana maszyna '$MachineId'. Dostepne: $ids"
    }
    return $entry
}

function Resolve-MachineSnapshotPath {
    param($Entry)
    $rel = [string]$Entry.snapshot
    if (-not $rel) { Fail "Maszyna '$($Entry.id)' bez pola snapshot w manifest" }
    $full = Join-Path $scriptDir (Join-Path "maszyny" $rel)
    if (-not (Test-Path $full)) { Fail "Brak zrzutu: $full" }
    return $full
}

function Get-PythonLauncher {
    foreach ($c in @("py", "python", "python3")) {
        if (Get-Command $c -ErrorAction SilentlyContinue) { return $c }
    }
    Fail "brak Pythona (py / python) do compare" 2
}

function Invoke-PythonCompare {
    param([string]$LeftPath, [string]$RightPath)
    $pyScript = Join-Path $scriptDir "porownaj-maszyny.py"
    if (-not (Test-Path $pyScript)) { Fail "brak porownaj-maszyny.py" }
    $py = Get-PythonLauncher
    $raw = & $py $pyScript $LeftPath $RightPath 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) {
        try { $err = $raw | ConvertFrom-Json; Fail $err.error } catch { Fail $raw.Trim() }
    }
    return $raw.Trim()
}

function Invoke-Machines {
    $manifest = Get-MachinesManifest
    $rows = @()
    foreach ($m in @($manifest.Machines)) {
        $snap = Join-Path $scriptDir (Join-Path "maszyny" ([string]$m.snapshot))
        $rows += [PSCustomObject]@{
            id            = $m.id
            label         = $m.label
            profile       = $m.profile
            snapshot      = $m.snapshot
            computerName  = $m.computerName
            role          = $m.role
            snapshotExists = (Test-Path $snap)
            snapshotPath  = $snap
        }
    }
    Emit @{
        ok = $true
        dir = (Join-Path $scriptDir "maszyny")
        machines = $rows
        hint = "compare -Machine <id>  |  compare -Machine a -OtherMachine b  |  compare-fleet"
    }
}

function Invoke-Compare {
    $left = Join-Path $scriptDir "srodowisko.json"
    $right = $null

    if ($Machine -and $OtherMachine) {
        $left = Resolve-MachineSnapshotPath (Get-MachineEntry $Machine)
        $right = Resolve-MachineSnapshotPath (Get-MachineEntry $OtherMachine)
    } elseif ($Machine) {
        if (-not (Test-Path $left)) { Fail "Brak lokalnego srodowisko.json - najpierw: ai.bat dump" }
        $right = Resolve-MachineSnapshotPath (Get-MachineEntry $Machine)
    } elseif ($Other) {
        $right = $Other
        if (-not [System.IO.Path]::IsPathRooted($right)) {
            $right = Join-Path $scriptDir $right
        }
        if (-not (Test-Path $left)) { Fail "Brak lokalnego srodowisko.json - najpierw: ai.bat dump" }
    } else {
        Fail "compare: podaj -Machine id, -Other plik, albo -Machine a -OtherMachine b"
    }

    if (-not (Test-Path $right)) { Fail "Brak pliku: $right" }
    Invoke-PythonCompare -LeftPath $left -RightPath $right
}

function Invoke-CompareFleet {
    $manifest = Get-MachinesManifest
    $list = @($manifest.Machines)
    if ($list.Count -lt 2) { Fail "compare-fleet: w manifest mniej niz 2 maszyny" }
    $pairs = @()
    for ($i = 0; $i -lt $list.Count; $i++) {
        for ($j = $i + 1; $j -lt $list.Count; $j++) {
            $a = $list[$i]
            $b = $list[$j]
            $leftPath = Resolve-MachineSnapshotPath $a
            $rightPath = Resolve-MachineSnapshotPath $b
            $raw = Invoke-PythonCompare -LeftPath $leftPath -RightPath $rightPath
            $data = $raw | ConvertFrom-Json
            $pairs += [PSCustomObject]@{
                leftId       = $a.id
                rightId      = $b.id
                same         = [bool]$data.same
                leftName     = $data.left.computerName
                rightName    = $data.right.computerName
                wingetOnlyLeft  = @($data.winget.onlyLeft).Count
                wingetOnlyRight = @($data.winget.onlyRight).Count
                wingetVerDiff   = @($data.winget.versionDiff).Count
                pipOnlyLeft     = @($data.pip.onlyLeft).Count
                pipOnlyRight    = @($data.pip.onlyRight).Count
                pipVerDiff      = @($data.pip.versionDiff).Count
                gapCount        = [int]$data.raport.gapCount
                topRisks        = @($data.raport.dependencyGaps | Select-Object -First 6 | ForEach-Object { $_.risk })
            }
        }
    }
    Emit @{ ok = $true; pairCount = $pairs.Count; pairs = $pairs; hint = "Pelny raport luk: ai.bat compare -Machine a -OtherMachine b (pole raport.dependencyGaps)" }
}

function Invoke-PipSync {
    $ref = $null
    if ($Machine) {
        $ref = Resolve-MachineSnapshotPath (Get-MachineEntry $Machine)
    } elseif ($Other) {
        $ref = $Other
        if (-not [System.IO.Path]::IsPathRooted($ref)) {
            $ref = Join-Path $scriptDir $ref
        }
    } else {
        Fail "pip-sync: podaj -Machine id (z manifestu) albo -Other sciezke do srodowisko.json"
    }
    if (-not (Test-Path $ref)) { Fail "Brak referencji: $ref" }

    $pyScript = Join-Path $scriptDir "aktualizuj-pip.py"
    if (-not (Test-Path $pyScript)) { Fail "brak aktualizuj-pip.py" }
    $py = Get-PythonLauncher
    $argList = @($pyScript, "--reference", $ref)
    if ($Apply) {
        if (-not $ConfirmApply) {
            Fail "pip-sync -Apply wymaga -ConfirmApply (globalny pip, nie venv). Najpierw plan bez -Apply."
        }
        $argList += "--apply"
        if ($Force) { $argList += "--force" }
    }

    $raw = & $py @argList 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) {
        try { $err = $raw | ConvertFrom-Json; Fail $err.error } catch { Fail $raw.Trim() }
    }
    $raw.Trim()
}

function Invoke-Diff {
    $p = Read-Profile
    $have = Get-ProfileIds $p
    $dumpIds = Get-DumpWingetIds
    if ($dumpIds.Count -eq 0) {
        Emit @{ ok = $true; note = "Brak srodowisko.json. Odpal najpierw: ai.bat dump"; missingInProfile = @(); extraInProfile = @() }
        return
    }
    $haveSet = [System.Collections.Generic.HashSet[string]]::new([string[]]$have, [StringComparer]::OrdinalIgnoreCase)
    $missing = @($dumpIds | Where-Object { -not $haveSet.Contains($_) } | Sort-Object -Unique)
    $dumpSet = [System.Collections.Generic.HashSet[string]]::new([string[]]$dumpIds, [StringComparer]::OrdinalIgnoreCase)
    $extra = @($have | Where-Object { -not $dumpSet.Contains($_) } | Sort-Object -Unique)
    Emit @{
        ok = $true
        missingInProfile = $missing
        inProfileNotInDump = $extra
        hint = "ai.bat fill -Section $Section  dopisze missingInProfile"
    }
}

function Invoke-Fill {
    $p = Read-Profile
    $dumpIds = Get-DumpWingetIds
    if ($dumpIds.Count -eq 0) { Fail "Brak zrzutu. Najpierw: ai.bat dump" }
    $have = Get-ProfileIds $p
    $haveSet = [System.Collections.Generic.HashSet[string]]::new([string[]]$have, [StringComparer]::OrdinalIgnoreCase)
    $toAdd = @($dumpIds | Where-Object { $_ -and -not $haveSet.Contains($_) } | Sort-Object -Unique)
    $sec = Get-Section $p $Section
    $added = @()
    if (-not $WhatIf) {
        $list = [System.Collections.Generic.List[object]]::new()
        foreach ($w in @($sec.Winget)) { $list.Add($w) }
        foreach ($pkgId in $toAdd) {
            $list.Add([PSCustomObject]@{ Name = $pkgId; Id = $pkgId; Checked = $true })
            $added += $pkgId
        }
        $sec.Winget = $list.ToArray()
        Save-Profile $p
    } else {
        $added = $toAdd
    }
    Emit @{
        ok = $true
        whatIf = [bool]$WhatIf
        section = $Section
        added = $added
        count = $added.Count
        profile = (Get-ProfilePath)
    }
}

function Invoke-AddWinget {
    if (-not $Id) { Fail "Podaj -Id (np. Anthropic.ClaudeCode)" }
    $p = Read-Profile
    $sec = Get-Section $p $Section
    $exists = @($sec.Winget) | Where-Object { $_.Id -eq $Id }
    if ($exists) {
        Emit @{ ok = $true; already = $true; id = $Id; section = $Section }
        return
    }
    $display = if ($Name) { $Name } else { $Id }
    if ($WhatIf) {
        Emit @{ ok = $true; whatIf = $true; wouldAdd = @{ Name = $display; Id = $Id; Section = $Section } }
        return
    }
    $list = [System.Collections.Generic.List[object]]::new()
    foreach ($w in @($sec.Winget)) { $list.Add($w) }
    $list.Add([PSCustomObject]@{ Name = $display; Id = $Id; Checked = $true })
    $sec.Winget = $list.ToArray()
    Save-Profile $p
    Emit @{ ok = $true; added = @{ Name = $display; Id = $Id }; section = $Section }
}

function Invoke-AddUrl {
    if (-not $Url) { Fail "Podaj -Url (strona albo bezposredni .exe/.msi)" }
    if (-not (Get-Command Resolve-InstallLink -ErrorAction SilentlyContinue)) { Fail "brak link-install.ps1" }
    $resolved = Resolve-InstallLink -InputText $Url
    if (-not $resolved.Ok) { Fail $resolved.Error }
    $pick = @($resolved.Candidates)[0]
    $saved = $null
    $code = $null
    if (-not $WhatIf) {
        $pp = Get-ProfilePath
        $saved = Add-LinkToProfile -ProfilePath $pp -SectionId $Section -Candidate $pick
        if ($Install) {
            if ($pick.Kind -eq "direct" -or ($pick.Url -and -not $pick.Id)) {
                $code = Install-DirectSilent -Url $pick.Url -Name $pick.Name
            } else {
                $code = Install-WingetSilent -PackageId $pick.Id
            }
        }
    }
    Emit @{
        ok = $true
        whatIf = [bool]$WhatIf
        query = $resolved.Query
        picked = $pick
        candidates = $resolved.Candidates
        saved = $saved
        installExit = $code
        section = $Section
    }
}

function Invoke-Image {
    $scriptPath = Join-Path $scriptDir "obraz-systemu.ps1"
    Emit @{
        ok = $true
        idea = "JSON w repo = przepis programow. Obraz = cale C: + partycje krytyczne (sterowniki, recovery). Po restore: upgrade z JSON, nie reinstall Windows."
        script = $scriptPath
        requires = @("Administrator", "drugi dysk NTFS (nie C:)", "Windows Backup (wbadmin)")
        noSysprep = "Sysprep/generalize psuje Docker, CAD i profil - nie uzywamy."
        backup = @{
            when = "2-3 dni po instalacji i dopieciu profilu; wczesniej dump + commit JSON"
            gui = "obraz-panel\\start.bat (osobne menu) lub start.bat -> obraz dysku"
            cli = "powershell -ExecutionPolicy Bypass -File .\obraz-systemu.ps1 -BackupTarget E"
            wbadmin = "wbadmin start backup -backupTarget:E: -include:C: -allCritical -quiet"
            before = "Checkpoint-Computer (skrypt robi sam); miejsce ~40+ GB na nosniku"
        }
        restore = @{
            preferred = "Windows RE: Ustawienia -> System -> Odzyskiwanie -> Przywroc obraz systemu (Advanced startup)"
            rePath = "Po restarcie: Rozwiaz problemy -> Zaawansowane -> Przywroc obraz komputera z obrazu systemu"
            wbadminList = "wbadmin get versions -backupTarget:E:"
            wbadminRecover = "wbadmin start recovery -version:MM/DD/YYYY-HH:MM -backupTarget:E: -recoveryTarget:C: (wersja z get versions)"
            warning = "Recovery nadpisuje C:. Nosnik z obrazem musi byc podlaczony."
        }
        afterRestore = @(
            "git pull w katalogu win11",
            ".\ai.bat test",
            ".\ai.bat upgrade",
            "py -m pip install -r python-requirements.txt",
            ".\ai.bat dump",
            ".\ai.bat diff"
        )
        docs = "OBRAZ-DYSKU.md"
        agent = "Agent nie odpala wbadmin - tylko image / image-check i instrukcja dla czlowieka."
    }
}

function Invoke-ImageCheck {
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    $wbadmin = Get-Command wbadmin -ErrorAction SilentlyContinue
    $volumes = @()
    Get-Volume | Where-Object { $_.DriveLetter } | ForEach-Object {
        $volumes += [PSCustomObject]@{
            letter = $_.DriveLetter
            label = $_.FileSystemLabel
            freeGb = [math]::Round($_.SizeRemaining / 1GB, 1)
            totalGb = [math]::Round($_.Size / 1GB, 1)
            okForBackupTarget = (($_.DriveLetter -ne 'C') -and ($_.FileSystem -match 'NTFS|ReFS'))
        }
    }
    $versions = $null
    $versionsError = $null
    if ($isAdmin -and $wbadmin) {
        try {
            $raw = wbadmin get versions 2>&1 | Out-String
            $versions = $raw.Trim()
        } catch { $versionsError = "$_" }
    }
    $cUsed = $null
    $sys = Get-PSDrive C -ErrorAction SilentlyContinue
    if ($sys) { $cUsed = [math]::Round($sys.Used / 1GB, 1) }
    Emit @{
        ok = $true
        isAdmin = $isAdmin
        wbadminFound = [bool]$wbadmin
        cUsedGb = $cUsed
        suggestedMinBackupGb = $(if ($cUsed) { [math]::Max(40, [math]::Ceiling($cUsed * 0.6)) } else { 40 })
        volumes = $volumes
        backupVersions = $versions
        backupVersionsError = $versionsError
        hint = if (-not $isAdmin) { "image-check bez Admin: tylko woluminy. Backup/restore: uruchom terminal jako Administrator." } else { "Wybor E (etc.): obraz-systemu.ps1 -BackupTarget E" }
    }
}

function Invoke-Upgrade {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { Fail "brak winget" 2 }
    if ($WhatIf) {
        $preview = winget upgrade --include-unknown 2>$null | Out-String
        Emit @{ ok = $true; whatIf = $true; preview = $preview }
        return
    }
    winget upgrade --all --accept-package-agreements --accept-source-agreements
    Emit @{ ok = $true; ran = "winget upgrade --all" }
}

switch ($Command.ToLower()) {
    "help"       { Invoke-Help }
    "test"       { Invoke-Test }
    "status"     { Invoke-Status }
    "dump"       { Invoke-Dump }
    "scan"       { Invoke-Scan }
    "profile"    { Invoke-ProfileShow }
    "list"       { Invoke-List }
    "diff"       { Invoke-Diff }
    "machines"   { Invoke-Machines }
    "compare"    { Invoke-Compare }
    "compare-fleet" { Invoke-CompareFleet }
    "pip-sync"      { Invoke-PipSync }
    "fill"       { Invoke-Fill }
    "add-winget" { Invoke-AddWinget }
    "add-url"    { Invoke-AddUrl }
    "validate"   { Invoke-Validate }
    "upgrade"    { Invoke-Upgrade }
    "image"      { Invoke-Image }
    "image-check"{ Invoke-ImageCheck }
    default      { Fail "Nieznane polecenie '$Command'. Uzyj: ai.bat help" }
}
