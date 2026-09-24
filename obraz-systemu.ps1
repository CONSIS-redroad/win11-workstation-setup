<#
.SYNOPSIS
    Zloty obraz czystego Windows 11 (2-3 dni po instalacji) na zewnetrzny dysk.
    Za 3 miesiace: wczytujesz obraz, potem upgrade programow (JSON + winget), bez reinstalacji od zera.

    UWAGA: pelny obraz wymaga DRUGIEGO dysku (USB/SSD). Nie zapisuj obrazu na C:.
    Sysprep / generalize NIE jest tu uzywany - psuje Docker, licencje CAD i profil uzytkownika.
#>
param(
    [string]$BackupTarget
)

$ErrorActionPreference = "Stop"
Write-Host "=== Obraz stanowiska (Windows Backup / wbadmin) ===" -ForegroundColor Cyan
Write-Host "JSON w repo to PRZEPIS. Ten skrypt robi ZDJNIECIE dysku (OS + programy + sterowniki)." -ForegroundColor Gray
Write-Host ""

# Punkt przywracania - tani, nie zastępuje obrazu
try {
    Checkpoint-Computer -Description "Przed-obrazem-stanowiska" -RestorePointType MODIFY_SETTINGS
    Write-Host "[OK] Punkt przywracania systemu utworzony." -ForegroundColor Green
} catch {
    Write-Host "[i] Punkt przywracania: $_" -ForegroundColor Yellow
}

Write-Host "`nDostepne woluminy (obraz musi trafic POZA C:):" -ForegroundColor Cyan
Get-Volume | Where-Object { $_.DriveLetter } | Format-Table DriveLetter, FileSystemLabel, @{N="GB_wolne";E={[math]::Round($_.SizeRemaining/1GB,1)}}, @{N="GB_razem";E={[math]::Round($_.Size/1GB,1)}} -AutoSize

$sys = Get-PSDrive C -ErrorAction SilentlyContinue
$needGb = 40
if ($sys) { $needGb = [math]::Max(40, [math]::Ceiling(($sys.Used / 1GB) * 0.6)) }
Write-Host "Szacunek: miej wolne okolo $needGb GB na nosniku backupu." -ForegroundColor Yellow

if (-not $BackupTarget) {
    $BackupTarget = Read-Host "Litera dysku backupu (np. E) albo Enter = tylko instrukcja, bez obrazu"
}

if (-not $BackupTarget) {
    Write-Host @"

Nie uruchomiono wbadmin. Zrob to gdy wlozysz SSD:

  powershell -ExecutionPolicy Bypass -File .\obraz-systemu.ps1 -BackupTarget E

Albo recznie:
  wbadmin start backup -backupTarget:E: -include:C: -allCritical -quiet

Za 3 miesiace:
  1. Odzyskaj obraz z Windows RE (Zaawansowane -> Przywroc obraz systemu)
     albo: wbadmin get versions / wbadmin start recovery
  2. Odpal to repo: git pull, start.bat
  3. winget upgrade --all
  4. py -m pip install -r python-requirements.txt
  5. Nie instaluj Windows od zera.

"@ -ForegroundColor Gray
    exit 0
}

$letter = $BackupTarget.Trim().TrimEnd(':').ToUpper()
if ($letter -eq "C") {
    Write-Host "Nie wolno zapisac obrazu na C:." -ForegroundColor Red
    exit 1
}
$vol = Get-Volume -DriveLetter $letter -ErrorAction SilentlyContinue
if (-not $vol) {
    Write-Host "Brak woluminu ${letter}:" -ForegroundColor Red
    exit 1
}

Write-Host "`nStart backupu C: (+ partycje systemowe) -> ${letter}:  (moze trwac długo)" -ForegroundColor Yellow
wbadmin start backup -backupTarget:"${letter}:" -include:C: -allCritical -quiet
if ($LASTEXITCODE -eq 0) {
    Write-Host "[OK] Obraz zapisany na ${letter}:" -ForegroundColor Green
} else {
    Write-Host "wbadmin kod $LASTEXITCODE - sprawdz czy Windows Backup jest dostepny i dysk jest NTFS." -ForegroundColor Red
    exit $LASTEXITCODE
}
