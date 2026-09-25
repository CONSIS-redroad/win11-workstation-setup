function Get-ObrazVolumes {
    $rows = @()
    Get-Volume | Where-Object { $_.DriveLetter -and $_.DriveLetter -ne 'C' } | ForEach-Object {
        $rows += [PSCustomObject]@{
            Letter   = $_.DriveLetter
            Label    = $_.FileSystemLabel
            FreeGb   = [math]::Round($_.SizeRemaining / 1GB, 1)
            TotalGb  = [math]::Round($_.Size / 1GB, 1)
            FileSystem = $_.FileSystem
            OkTarget = ($_.FileSystem -match 'NTFS|ReFS')
        }
    }
    return @($rows | Sort-Object Letter)
}

function Get-CSystemUsedBytes {
    $sys = Get-PSDrive C -ErrorAction SilentlyContinue
    if (-not $sys) { return 0 }
    return [long]$sys.Used
}

function Get-SuggestedBackupGb {
    param([long]$UsedBytes)
    $usedGb = $UsedBytes / 1GB
    return [int][math]::Max(40, [math]::Ceiling($usedGb * 0.65))
}

function Get-BackupFolderSize {
    param([string]$Letter)
    $root = "${Letter}:\WindowsImageBackup"
    if (-not (Test-Path -LiteralPath $root)) { return 0 }
    $sum = 0L
    Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
        $sum += $_.Length
    }
    return $sum
}

function Invoke-ObrazCheckpoint {
    try {
        Checkpoint-Computer -Description "Przed-backupem-ObrazPanel" -RestorePointType MODIFY_SETTINGS | Out-Null
        return @{ ok = $true; message = "Punkt przywracania utworzony." }
    } catch {
        return @{ ok = $false; message = "Punkt przywracania: $_ (Windows czasem 1/dobe)." }
    }
}

function Get-WbadminVersions {
    param([string]$Letter)
    $target = "${Letter}:"
    if (-not (Get-Command wbadmin -ErrorAction SilentlyContinue)) {
        return @{ ok = $false; error = "Brak wbadmin (Windows Backup)."; raw = $null; versions = @() }
    }
    $raw = & wbadmin get versions -backupTarget:$target 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) {
        return @{ ok = $false; error = $raw.Trim(); raw = $raw; versions = @() }
    }
    $versions = @()
    foreach ($line in ($raw -split "`n")) {
        if ($line -match '(?i)(version|wersja).*?(identifier|identyfikator)\s*:\s*(.+)') {
            $versions += [PSCustomObject]@{ VersionId = $Matches[3].Trim(); Line = $line.Trim() }
        }
        elseif ($line -match '(?i)(identifier|identyfikator)\s*(?:wersji)?\s*:\s*(.+)') {
            $versions += [PSCustomObject]@{ VersionId = $Matches[2].Trim(); Line = $line.Trim() }
        }
    }
    if ($versions.Count -eq 0) {
        foreach ($line in ($raw -split "`n")) {
            if ($line -match '(\d{1,2}[./]\d{1,2}[./]\d{4}-\d{1,2}:\d{2})') {
                $id = $Matches[1] -replace '\.', '/'
                $versions += [PSCustomObject]@{ VersionId = $id; Time = $id; Line = $line.Trim() }
            }
        }
    }
    return @{ ok = $true; error = $null; raw = $raw; versions = $versions }
}

function Start-ObrazBackup {
    param([string]$Letter)
    $target = "${Letter}:"
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "wbadmin"
    $psi.Arguments = "start backup -backupTarget:$target -include:C: -allCritical -quiet"
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $proc = [System.Diagnostics.Process]::Start($psi)
    return $proc
}

function Open-WindowsRecoveryHelp {
    Start-Process "ms-settings:recovery"
}
