<#
.SYNOPSIS
    Link ze strony -> winget (cicho) albo bezposredni EXE/MSI.
    Dot-source z s.ps1 / cli.ps1.
#>

function Search-WingetPackages {
    param([string]$Query, [int]$Limit = 8)
    $result = New-Object System.Collections.Generic.List[object]
    if (-not $Query -or -not (Get-Command winget -ErrorAction SilentlyContinue)) { return @() }

    $raw = & winget search --query $Query --accept-source-agreements --disable-interactivity 2>$null
    $lines = @($raw | ForEach-Object { [string]$_ })
    $header = $null
    $dataStart = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^Name\s+Id\b') {
            $header = $lines[$i]
            $dataStart = $i + 1
            if (($i + 1) -lt $lines.Count -and $lines[$i + 1] -match '^-+') { $dataStart = $i + 2 }
            break
        }
    }
    if (-not $header -or $dataStart -lt 0) { return @() }
    $idAt = $header.IndexOf("Id")
    $verAt = $header.IndexOf("Version")
    $srcAt = $header.IndexOf("Source")
    if ($idAt -lt 0) { return @() }
    if ($verAt -lt 0) { $verAt = $header.Length }
    if ($srcAt -lt 0) { $srcAt = $header.Length }

    for ($i = $dataStart; $i -lt $lines.Count; $i++) {
        $s = $lines[$i]
        if ($s.Trim() -eq "" -or $s.Length -le $idAt) { continue }
        $pkgName = $s.Substring(0, [Math]::Min($idAt, $s.Length)).Trim()
        $endId = [Math]::Min($verAt, $s.Length)
        $pkgId = $s.Substring($idAt, [Math]::Max(0, $endId - $idAt)).Trim()
        $ver = ""
        if ($s.Length -gt $verAt) {
            $endVer = [Math]::Min($srcAt, $s.Length)
            $ver = $s.Substring($verAt, [Math]::Max(0, $endVer - $verAt)).Trim()
        }
        if (-not $pkgId -or $pkgId -in @("Id", "Version", "Source")) { continue }
        $result.Add([PSCustomObject]@{ Name = $pkgName; Id = $pkgId; Version = $ver; Kind = "winget" }) | Out-Null
        if ($result.Count -ge $Limit) { break }
    }
    if ($result.Count -eq 0) { return @() }
    return $result.ToArray()
}

function Get-HtmlTitle {
    param([string]$Url)
    try {
        $resp = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 12 -MaximumRedirection 4
        $ct = [string]$resp.Headers["Content-Type"]
        if ($ct -match "octet-stream|application/(x-msdownload|exe|msi)") { return $null }
        $html = $resp.Content
        if ($html -is [byte[]]) { return $null }
        $text = [string]$html
        if ($text.Length -gt 400000) { $text = $text.Substring(0, 400000) }
        if ($text -match '(?is)<title[^>]*>([^<]+)') {
            $t = $Matches[1] -replace '\s+', ' '
            $t = $t -replace '\s*[|].*$', ''
            return $t.Trim()
        }
    } catch {}
    return $null
}

function Resolve-InstallLink {
    param([string]$InputText)

    $raw = ([string]$InputText).Trim().Trim('"').Trim("'")
    if (-not $raw) {
        return [PSCustomObject]@{ Ok = $false; Error = "Wklej URL albo nazwe pakietu."; Candidates = @() }
    }

    $kind = "search"
    $query = $raw
    $directUrl = $null
    $hintId = $null
    $pageTitle = $null

    if ($raw -match '^https?://') {
        $u = $raw
        if ($u -match '(?i)\.(exe|msi|msix|appx)(\?|#|$)') {
            $kind = "direct"
            $directUrl = $u
            $leaf = [IO.Path]::GetFileName(([Uri]$u).AbsolutePath)
            $query = [IO.Path]::GetFileNameWithoutExtension($leaf) -replace '%20', ' '
        }
        elseif ($u -match 'winstall\.app/apps/([^/?#]+)') {
            $hintId = $Matches[1]
            $query = $hintId
            $kind = "winget-id"
        }
        elseif ($u -match 'winget\.run/pkg/([^/]+)/([^/?#]+)') {
            $hintId = "$($Matches[1]).$($Matches[2])"
            $query = $hintId
            $kind = "winget-id"
        }
        elseif ($u -match 'github\.com/([^/]+)/([^/?#]+)') {
            $repo = $Matches[2] -replace '\.git$', ''
            $query = ($repo -replace '[-_]', ' ')
            $kind = "github"
        }
        else {
            $pageTitle = Get-HtmlTitle $u
            try {
                $hostName = ([Uri]$u).Host -replace '^www\.', ''
                $seg = ([Uri]$u).Segments | Where-Object { $_ -and $_ -ne '/' } | Select-Object -Last 1
                $seg = ($seg -replace '/', '') -replace '-', ' '
            } catch { $hostName = ""; $seg = "" }
            if ($pageTitle) { $query = $pageTitle }
            elseif ($seg) { $query = $seg }
            else { $query = ($hostName -split '\.')[0] }
            $kind = "page"
        }
    }
    elseif ($raw -match '^[\w][\w\.\-]{2,}\.[\w\.\-]{2,}$') {
        $hintId = $raw
        $query = $raw
        $kind = "winget-id"
    }

    $candidates = @()
    if ($kind -eq "direct") {
        $name = if ($query) { $query } else { "Instalator z URL" }
        $candidates += [PSCustomObject]@{
            Kind = "direct"; Name = $name; Id = ""; Url = $directUrl; Version = "URL"
            Label = "Bezposredni plik (cichy EXE/MSI)"
        }
        $fromWinget = Search-WingetPackages $query 5
        $candidates += $fromWinget
    }
    else {
        if ($hintId) {
            $exact = Search-WingetPackages $hintId 5
            $hit = @($exact | Where-Object { $_.Id -eq $hintId })
            if ($hit.Count -eq 0) { $hit = $exact }
            $candidates += $hit
        }
        $more = Search-WingetPackages $query 8
        foreach ($m in $more) {
            if (-not ($candidates | Where-Object { $_.Id -eq $m.Id })) { $candidates += $m }
        }
        if ($pageTitle -and $pageTitle -ne $query) {
            foreach ($m in (Search-WingetPackages $pageTitle 5)) {
                if (-not ($candidates | Where-Object { $_.Id -eq $m.Id })) { $candidates += $m }
            }
        }
    }

    return [PSCustomObject]@{
        Ok          = ($candidates.Count -gt 0)
        Error       = if ($candidates.Count -eq 0) { "Nie znaleziono w winget. Sprobuj innej nazwy albo wklej bezposredni link do .exe/.msi." } else { $null }
        Kind        = $kind
        Query       = $query
        PageTitle   = $pageTitle
        Source      = $raw
        Candidates  = @($candidates | Select-Object -First 10)
    }
}

function Install-WingetSilent {
    param([string]$PackageId)
    winget install --id $PackageId --exact -e --silent --accept-package-agreements --accept-source-agreements --disable-interactivity
    return $LASTEXITCODE
}

function Install-DirectSilent {
    param([string]$Url, [string]$Name = "paczka")
    $ext = ".exe"
    if ($Url -match '(?i)\.(msi)(\?|$)') { $ext = ".msi" }
    $dest = Join-Path $env:TEMP (("{0}_{1}{2}" -f ($Name -replace '[^a-zA-Z0-9]', '_'), (Get-Random), $ext))
    & curl.exe -L --retry 2 -o $dest $Url
    if (-not (Test-Path $dest)) { throw "Nie pobrano pliku z URL." }
    if ($ext -eq ".msi") {
        $p = Start-Process -FilePath "msiexec.exe" -ArgumentList @("/i", $dest, "/qn", "/norestart") -Wait -PassThru
        return $p.ExitCode
    }
    $argsTry = @("/S", "/silent", "/quiet", "/VERYSILENT")
    $p = Start-Process -FilePath $dest -ArgumentList "/S" -Wait -PassThru
    return $p.ExitCode
}

function Add-LinkToProfile {
    param(
        [string]$ProfilePath,
        [string]$SectionId,
        $Candidate
    )
    $data = Get-Content $ProfilePath -Raw -Encoding UTF8 | ConvertFrom-Json
    $sec = @($data.Sections) | Where-Object { $_.Id -eq $SectionId } | Select-Object -First 1
    if (-not $sec) { throw "Brak sekcji $SectionId" }

    if ($Candidate.Kind -eq "direct" -or ($Candidate.Url -and -not $Candidate.Id)) {
        if (-not ($sec.PSObject.Properties.Name -contains "DirectInstalls")) {
            $sec | Add-Member -NotePropertyName DirectInstalls -NotePropertyValue @() -Force
        }
        foreach ($d in @($sec.DirectInstalls)) {
            if ($d.Url -eq $Candidate.Url) { return "already-direct" }
        }
        $list = [System.Collections.Generic.List[object]]::new()
        foreach ($d in @($sec.DirectInstalls)) { $list.Add($d) }
        $list.Add([PSCustomObject]@{
            Name    = $Candidate.Name
            Url     = $Candidate.Url
            Args    = "/S"
            Checked = $true
        })
        $sec.DirectInstalls = $list.ToArray()
        $data | ConvertTo-Json -Depth 12 | Set-Content -Path $ProfilePath -Encoding UTF8
        return "added-direct"
    }

    foreach ($w in @($sec.Winget)) {
        if ($w.Id -eq $Candidate.Id) { return "already-winget" }
    }
    $list = [System.Collections.Generic.List[object]]::new()
    foreach ($w in @($sec.Winget)) { $list.Add($w) }
    $list.Add([PSCustomObject]@{ Name = $Candidate.Name; Id = $Candidate.Id; Checked = $true })
    $sec.Winget = $list.ToArray()
    $data | ConvertTo-Json -Depth 12 | Set-Content -Path $ProfilePath -Encoding UTF8
    return "added-winget"
}
