# Obraz dysku (zloty backup)

**Przepis** = `profil_*.json` + `srodowisko.json` w gicie. **Obraz** = cale Windows z programami i sterownikami na drugim dysku. Po kwartale wczytujesz obraz, potem tylko aktualizujesz pakiety — bez instalacji Windows od zera.

AI: `.\ai.bat image` (runbook JSON), `.\ai.bat image-check` (dyski, Admin). Agent **nie** odpala `wbadmin` za Ciebie.

## Kiedy zrobic obraz

1. Swiezy Win11, profil dopiety (`start.bat` lub winget z JSON).
2. `ai.bat dump` + commit zrzutu (masz przepis na potem).
3. **2–3 dni** uzytkowania (stabilne sterowniki, Docker/CAD jesli uzywasz).
4. Obraz na **USB/SSD NTFS**, nigdy na **C:**.

## Backup (Admin)

**Panel obrazu (osobne menu):** `obraz-panel\start.bat` — wybor nosnika, postep backupu, lista wersji do przywrocenia.

**Glowny ConsisAI:** `start.bat` → Konfiguracja → obraz dysku (otwiera ten sam panel).

**CLI:**

```powershell
# Administrator
cd C:\sciezka\do\win11
powershell -ExecutionPolicy Bypass -File .\obraz-systemu.ps1 -BackupTarget E
```

Recznie (to samo co skrypt):

```text
wbadmin start backup -backupTarget:E: -include:C: -allCritical -quiet
```

Skrypt robi tez punkt przywracania (Checkpoint-Computer) — nie zastepuje obrazu, ale pomaga przed backupem.

**Nie uzywaj sysprep / generalize** — psuje Docker, licencje CAD, profil uzytkownika.

## Restore (czlowiek, boot z RE)

1. Podlacz nosnik z obrazem.
2. **Ustawienia → System → Odzyskiwanie → Przywroc obraz systemu** (restart do Windows RE).

   Albo: przy starcie **Shift + Restart** → Rozwiaz problemy → Zaawansowane opcje → **Przywroc obraz komputera z obrazu systemu**.

3. Wskaz wersje z nosnika (data z czasu backupu).

**Admin w dzialajacym systemie** (rzadziej, ostroznie):

```text
wbadmin get versions -backupTarget:E:
wbadmin start recovery -version:MM/DD/YYYY-HH:MM -backupTarget:E: -recoveryTarget:C:
```

(wersje z `get versions`).

## Po wczytaniu obrazu

```text
git pull
.\ai.bat test
.\ai.bat upgrade
py -m pip install -r python-requirements.txt
.\ai.bat dump
.\ai.bat diff
```

Opcjonalnie: `pip-sync` / profil — gdy celowo dociagasz stack; patrz ROADMAP Faza B.

## Ograniczenia

- Potrzebny duzy nosnik (czesto 40 GB+, zalezy od zajetosci C:).
- Obraz nie zastapi recovery partition na innym sprzecie (inny PC = inny hardware).
- `WindowsImageBackup/` na nosniku — **nie commituj** do gita (w `.gitignore`).

## Microsoft

- [wbadmin start backup](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/wbadmin-start-backup)
- [Checkpoint-Computer](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/checkpoint-computer) (limit ~1/dobe)
