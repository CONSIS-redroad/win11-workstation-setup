# AI CLI - konfigurator stanowiska
#
# Odpalaj z katalogu pakietu (bez GUI, JSON na stdout):
#   .\ai.bat test
#   .\ai.bat status
#   .\ai.bat dump
#   .\ai.bat diff
#   .\ai.bat fill -Section dev
#   .\ai.bat add-winget -Section ai-cli -Id Anthropic.ClaudeCode -Name "Claude Code"
#
# Caly stdout ma byc JSON (oprocz help). Kod wyjscia: 0 OK, 1 blad, 2 brak narzedzia.

param(
    [Parameter(Position = 0)]
    [string]$Command = "help",

    [string]$Profile = "profil_msi.json",
    [string]$Section = "dev",
    [string]$Id = "",
    [string]$Name = "",
    [string]$Url = "",
    [switch]$Install,
    [switch]$WhatIf
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
            @{ cmd = "test";      use = "szybki test: pliki, JSON, git/gh/python/docker/node/claude/cursor" }
            @{ cmd = "status";    use = "narzedzia + czy sa zrzuty" }
            @{ cmd = "dump";      use = "zrzut srodowiska -> srodowisko.json" }
            @{ cmd = "scan";      use = "audyt tweakow -> raport_stanu_<PC>.json" }
            @{ cmd = "profile";   use = "wypisz profil JSON" }
            @{ cmd = "list";      use = "lista pakietow z profilu" }
            @{ cmd = "diff";      use = "winget zrzut vs profil (czego brakuje w przepisie)" }
            @{ cmd = "fill";      use = "dopisz brakujace ID winget do sekcji (-Section, domyslnie dev)" }
            @{ cmd = "add-url";    use = "link ze strony -> winget: -Url https://...  [-Section dev] [-Install]" }
            @{ cmd = "validate";  use = "sprawdz JSON-y" }
            @{ cmd = "upgrade";   use = "winget upgrade --all (wymaga sieci)" }
        )
        examples = @(
            ".\ai.bat test",
            ".\ai.bat dump",
            ".\ai.bat diff",
            ".\ai.bat fill -Section ai-cli",
            ".\ai.bat add-url -Url https://git-scm.com -Section dev -Install"
        )
    }
}

function Invoke-Validate {
    $problems = @()
    $files = @("profil_msi.json", "ust_2.json")
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
    $toolsWanted = @("winget", "git", "gh", "python", "node")
    $missing = @()
    $present = @()
    foreach ($n in $toolsWanted) {
        $t = Get-Tool $n
        if ($t.found) { $present += $t } else { $missing += $n }
    }
    $ai = @("claude", "cursor") | ForEach-Object { Get-Tool $_ }
    $problems = @()
    foreach ($f in @("profil_msi.json", "cli.ps1", "zrzut-srodowiska.ps1")) {
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
    "fill"       { Invoke-Fill }
    "add-winget" { Invoke-AddWinget }
    "add-url"    { Invoke-AddUrl }
    "validate"   { Invoke-Validate }
    "upgrade"    { Invoke-Upgrade }
    default      { Fail "Nieznane polecenie '$Command'. Uzyj: ai.bat help" }
}
