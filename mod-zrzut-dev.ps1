<#
.SYNOPSIS
    Zrzut pip + ustawien Cursor / VS Code / Google Antigravity (IDE + CLI).
    Dot-source: . .\mod-zrzut-dev.ps1  potem Get-DevToolSnapshot
    Sekrety (klucze, tokeny, env MCP) zamieniane na ***.

.NOTES
    Sciezki (Windows, 2026):
    - Cursor:  %APPDATA%\Cursor\User\settings.json
    - VS Code: %APPDATA%\Code\User\settings.json
      https://code.visualstudio.com/docs/configure/settings
    - Antigravity IDE 1.x: %APPDATA%\Antigravity\User
      rozszerzenia: %USERPROFILE%\.antigravity\extensions
    - Antigravity IDE 2.0: %APPDATA%\Antigravity IDE\User
      rozszerzenia: %USERPROFILE%\.antigravity-ide\extensions
      https://discuss.ai.google.dev/t/fix-for-antigravity-2-0-hijacking-the-ide-and-how-to-restore-your-lost-settings-extensions-for-windows-user/146158
    - Antigravity CLI: %USERPROFILE%\.gemini\antigravity-cli\settings.json
      bin: %LOCALAPPDATA%\agy\bin\agy.exe
      https://www.antigravity.google/docs/cli/install
#>

function ConvertFrom-JsonC {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return $null }
    try { return $Text | ConvertFrom-Json } catch {}
    $noBlock = [regex]::Replace($Text, '/\*[\s\S]*?\*/', '')
    $lines = foreach ($line in ($noBlock -split "`n")) {
        $inStr = $false
        $chars = $line.ToCharArray()
        $cut = $chars.Length
        for ($i = 0; $i -lt $chars.Length; $i++) {
            $c = $chars[$i]
            if ($c -eq '"' -and ($i -eq 0 -or $chars[$i - 1] -ne '\')) { $inStr = -not $inStr }
            elseif (-not $inStr -and $c -eq '/' -and ($i + 1) -lt $chars.Length -and $chars[$i + 1] -eq '/') {
                $cut = $i
                break
            }
        }
        if ($cut -eq 0) { "" }
        elseif ($cut -lt $chars.Length) { -join $chars[0..($cut - 1)] }
        else { $line }
    }
    try { return ($lines -join "`n") | ConvertFrom-Json } catch { return $null }
}

function Test-SecretName {
    param([string]$Name)
    if (-not $Name) { return $false }
    return [bool]($Name -match '(?i)(api[-_]?key|access[-_]?token|auth(entication|orization)?|pass(word|wd)|secret|credential|private[-_]?key|client[-_]?secret|refresh[-_]?token|^env$|^headers$)')
}

function Test-SecretValue {
    param($Value)
    if ($Value -isnot [string]) { return $false }
    return [bool]($Value -match '(?i)^(sk-|sk-ant-|ghp_|github_pat_|xox[baprs]-|AIza|eyJ[A-Za-z0-9_-]{20,}|AKIA[0-9A-Z]{16})')
}

function ConvertTo-PublicPath {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $Path }
    $p = $Path
    foreach ($pair in @(
            @{ env = $env:USERPROFILE; token = '%USERPROFILE%' }
            @{ env = $env:APPDATA; token = '%APPDATA%' }
            @{ env = $env:LOCALAPPDATA; token = '%LOCALAPPDATA%' }
        )) {
        if (-not $pair.env) { continue }
        $root = $pair.env.TrimEnd('\')
        if ($p.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) {
            return $pair.token + $p.Substring($root.Length)
        }
    }
    return $p
}

function Protect-DevSecrets {
    param($Node, [int]$Depth = 0)
    if ($null -eq $Node -or $Depth -gt 12) { return $Node }
    if ($Node -is [System.Collections.IEnumerable] -and $Node -isnot [string] -and $Node -isnot [hashtable] -and $Node -isnot [pscustomobject]) {
        $acc = @()
        foreach ($item in @($Node)) { $acc += ,(Protect-DevSecrets $item ($Depth + 1)) }
        return $acc
    }
    $props = $null
    if ($Node -is [hashtable]) { $props = @($Node.Keys) }
    elseif ($Node -is [pscustomobject]) { $props = @($Node.PSObject.Properties.Name) }
    if (-not $props) { return $Node }
    foreach ($name in $props) {
        $val = if ($Node -is [hashtable]) { $Node[$name] } else { $Node.$name }
        $next = if ((Test-SecretName $name) -or (Test-SecretValue $val)) {
            if ($val -is [string] -or $null -eq $val) { '***' }
            elseif ($name -match '(?i)^(env|headers)$') { '***' }
            else { Protect-DevSecrets $val ($Depth + 1) }
        } else {
            Protect-DevSecrets $val ($Depth + 1)
        }
        if ($Node -is [hashtable]) { $Node[$name] = $next } else { $Node.$name = $next }
    }
    return $Node
}

function Read-JsonFileSafe {
    param([string]$Path)
    $row = [PSCustomObject]@{
        exists   = $false
        path     = (ConvertTo-PublicPath $Path)
        data     = $null
        error    = $null
        redacted = $false
    }
    if (-not $Path -or -not (Test-Path -LiteralPath $Path)) { return $row }
    $row.exists = $true
    try {
        $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
        $parsed = ConvertFrom-JsonC $raw
        if ($null -eq $parsed) { $row.error = "nie da sie sparsowac JSON/JSONC"; return $row }
        $row.data = Protect-DevSecrets $parsed
        $row.redacted = $true
    } catch {
        $row.error = "$_"
    }
    return $row
}

function Get-IdeExtensions {
    param([string]$Cli, [string]$ExtDir)
    $list = @()
    if ($Cli -and (Get-Command $Cli -ErrorAction SilentlyContinue)) {
        $rows = & $Cli --list-extensions --show-versions 2>$null
        foreach ($r in @($rows)) {
            if ($r -match '^(.+)@(.+)$') {
                $list += [PSCustomObject]@{ Id = $Matches[1]; Version = $Matches[2] }
            } elseif ($r) {
                $list += [PSCustomObject]@{ Id = $r.Trim(); Version = "" }
            }
        }
        return @($list)
    }
    if ($ExtDir -and (Test-Path -LiteralPath $ExtDir)) {
        Get-ChildItem -LiteralPath $ExtDir -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $n = $_.Name -replace '-\d+(\.\d+)*$', ''
            $list += [PSCustomObject]@{ Id = $n; Version = "" }
        }
    }
    return @($list)
}

function Get-McpServersSafe {
    param([string]$Path)
    $file = Read-JsonFileSafe $Path
    $servers = @()
    $root = $null
    if ($file.data) { $root = $file.data.mcpServers }
    if ($root) {
        foreach ($p in @($root.PSObject.Properties)) {
            $v = $p.Value
            $servers += [PSCustomObject]@{
                name    = $p.Name
                command = $v.command
                type    = $v.type
                hasUrl  = [bool]$v.url
                hasEnv  = [bool]$v.env
            }
        }
    }
    return [PSCustomObject]@{
        exists  = $file.exists
        path    = (ConvertTo-PublicPath $Path)
        error   = $file.error
        servers = @($servers)
    }
}

function Get-VscodeForkSnapshot {
    param(
        [string]$Id,
        [string]$RoamingName,
        [string]$ExtDirName,
        [string[]]$CliNames
    )
    $userDir = Join-Path $env:APPDATA $RoamingName
    $userDir = Join-Path $userDir "User"
    $settingsPath = Join-Path $userDir "settings.json"
    $keysPath = Join-Path $userDir "keybindings.json"
    $extDir = if ($ExtDirName) { Join-Path $env:USERPROFILE $ExtDirName } else { $null }
    if ($extDir) { $extDir = Join-Path $extDir "extensions" }

    $cli = $null
    $cliPath = $null
    foreach ($n in @($CliNames)) {
        $cmd = Get-Command $n -ErrorAction SilentlyContinue
        if ($cmd) { $cli = $n; $cliPath = $cmd.Source; break }
    }

    $settings = Read-JsonFileSafe $settingsPath
    $keys = Read-JsonFileSafe $keysPath
    $ext = Get-IdeExtensions $cli $extDir

    $present = [bool](
        (Test-Path -LiteralPath $userDir) -or
        $cli -or
        ($extDir -and (Test-Path -LiteralPath $extDir))
    )

    return [PSCustomObject]@{
        id              = $Id
        present         = $present
        cli             = $cli
        cliPath         = (ConvertTo-PublicPath $cliPath)
        userDir         = (ConvertTo-PublicPath $userDir)
        settingsPath    = (ConvertTo-PublicPath $settingsPath)
        settingsExists  = $settings.exists
        settings        = $settings.data
        settingsError   = $settings.error
        keybindings     = $keys.data
        keybindingsExists = $keys.exists
        extensions      = @($ext)
        extensionCount  = @($ext).Count
    }
}

function Get-PipSnapshot {
    param([string]$RequirementsPath)
    $interpreters = @()
    $py = $null
    foreach ($c in @("py", "python", "python3")) {
        $cmd = Get-Command $c -ErrorAction SilentlyContinue
        if (-not $cmd) { continue }
        $ver = $null
        $exe = $null
        try {
            $ver = (& $c --version 2>$null | Select-Object -First 1)
            $exe = $cmd.Source
        } catch {}
        $interpreters += [PSCustomObject]@{ name = $c; path = (ConvertTo-PublicPath $exe); version = $ver }
        if (-not $py) { $py = $c }
    }

    $packages = @()
    $freezeLines = @()
    $mcpVer = $null
    $notable = @{}
    if ($py) {
        $jsonOut = & $py -m pip list --format json 2>$null
        if ($jsonOut) {
            try {
                $parsed = $jsonOut | ConvertFrom-Json
                foreach ($pkg in @($parsed)) {
                    $packages += [PSCustomObject]@{ Name = [string]$pkg.name; Version = [string]$pkg.version }
                    $ln = $pkg.name.ToLowerInvariant()
                    if ($ln -in @("mcp", "fastmcp", "langgraph", "litellm", "detect-secrets", "gitleaks")) {
                        $notable[$ln] = [string]$pkg.version
                    }
                    if ($ln -eq "mcp") { $mcpVer = [string]$pkg.version }
                }
            } catch {}
        }
        $freezeLines = @(& $py -m pip freeze 2>$null)
        if ($RequirementsPath) {
            @($freezeLines) | Set-Content -Path $RequirementsPath -Encoding UTF8
        }
    }

    $mcpMajor = $null
    if ($mcpVer -match '^(\d+)') { $mcpMajor = [int]$Matches[1] }
    $mcpWarn = ($null -ne $mcpMajor -and $mcpMajor -ge 2)

    return [PSCustomObject]@{
        interpreter     = $py
        interpreters    = @($interpreters)
        packageCount    = @($packages).Count
        packages        = @($packages)
        notable         = [PSCustomObject]$notable
        mcpVersion      = $mcpVer
        mcpMajor        = $mcpMajor
        mcpPinWarning   = $mcpWarn
        mcpPinHint      = $(if ($mcpWarn) { "mcp $mcpVer ma major>=2; FastMCP 1.x-style import moze padac. Pin mcp>=1.8,<2 w przepisie." } else { $null })
        requirements    = $(if ($RequirementsPath) { Split-Path -Leaf $RequirementsPath } else { $null })
    }
}

function Get-AntigravitySnapshot {
    $ide1 = Get-VscodeForkSnapshot -Id "antigravity-1" -RoamingName "Antigravity" -ExtDirName ".antigravity" -CliNames @("antigravity")
    $ide2 = Get-VscodeForkSnapshot -Id "antigravity-ide-2" -RoamingName "Antigravity IDE" -ExtDirName ".antigravity-ide" -CliNames @()

    $cliSettings = Join-Path $env:USERPROFILE ".gemini\antigravity-cli\settings.json"
    $cliKeys = Join-Path $env:USERPROFILE ".gemini\antigravity-cli\keybindings.json"
    $cliBin = Join-Path $env:LOCALAPPDATA "agy\bin\agy.exe"
    $agy = Get-Command "agy" -ErrorAction SilentlyContinue

    $cli = [PSCustomObject]@{
        present        = [bool]((Test-Path -LiteralPath $cliBin) -or $agy -or (Test-Path -LiteralPath (Split-Path $cliSettings)))
        binPath        = (ConvertTo-PublicPath $cliBin)
        binExists      = (Test-Path -LiteralPath $cliBin)
        cliOnPath      = [bool]$agy
        cliPath        = $(if ($agy) { ConvertTo-PublicPath $agy.Source } else { $null })
        settingsPath   = (ConvertTo-PublicPath $cliSettings)
        settingsExists = (Test-Path -LiteralPath $cliSettings)
        settings       = (Read-JsonFileSafe $cliSettings).data
        keybindings    = (Read-JsonFileSafe $cliKeys).data
    }

    return [PSCustomObject]@{
        ideV1   = $ide1
        ideV2   = $ide2
        cli     = $cli
        present = [bool]($ide1.present -or $ide2.present -or $cli.present)
        sources = @(
            "https://www.antigravity.google/docs/cli/install",
            "https://www.antigravity.google/docs/cli/settings/",
            "https://discuss.ai.google.dev/t/fix-for-antigravity-2-0-hijacking-the-ide-and-how-to-restore-your-lost-settings-extensions-for-windows-user/146158"
        )
    }
}

function Get-DevToolSnapshot {
    param(
        [string]$RequirementsPath,
        [switch]$SkipRequirements
    )
    $req = $null
    if (-not $SkipRequirements) { $req = $RequirementsPath }

    $python = Get-PipSnapshot -RequirementsPath $req
    $cursor = Get-VscodeForkSnapshot -Id "cursor" -RoamingName "Cursor" -ExtDirName ".cursor" -CliNames @("cursor")
    $cursor | Add-Member -NotePropertyName mcp -NotePropertyValue (Get-McpServersSafe (Join-Path $env:USERPROFILE ".cursor\mcp.json")) -Force
    $vscode = Get-VscodeForkSnapshot -Id "vscode" -RoamingName "Code" -ExtDirName ".vscode" -CliNames @("code")
    $anti = Get-AntigravitySnapshot

    return [PSCustomObject]@{
        CapturedAt  = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        Python      = $python
        Cursor      = $cursor
        VsCode      = $vscode
        Antigravity = $anti
        Sources     = @(
            "https://code.visualstudio.com/docs/configure/settings",
            "Cursor User: %APPDATA%\Cursor\User\settings.json",
            "VS Code User: %APPDATA%\Code\User\settings.json"
        )
    }
}
