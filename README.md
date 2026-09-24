# Konfigurator stanowiska Windows 11

## Po co to jest (klucz)

Dwa byty, których nie wolno mylić:

| Warstwa | Co to jest | Po co |
| --- | --- | --- |
| **JSON w gicie** | Przepis środowiska | AI i Ty **edytujecie plik** (pakiety, pip, dodatki Cursor). To kopia stanowiska, którą da się czytać i poprawiać bez klików. |
| **Obraz dysku** | Zdjęcie czystego Windows (teraz, 2–3 dni po instalacji) | Za 3 miesiące **wczytujesz obraz**, nie stawiasz systemu od zera. Potem tylko `winget upgrade --all` + ewentualnie `pip install -r python-requirements.txt`. |

WinUtil, GstarCAD i GUI są narzędziami. **Wartością repo jest: środowisko jako JSON + złoty obraz, nie kolejny debloat.**

Modele AI łatwo zjadają JSON (biblioteki, rozszerzenia, ID winget). Nie lubią odtwarzać klikanej konfiguracji z pamięci. Dlatego zrzut idzie do `srodowisko.json`, a świadomy przepis do `profil_*.json`.

**Zakładka „Z linku”:** wklejasz URL ze strony (albo `Git.Git`, albo bezpośredni `.exe`). Program szuka w winget i instaluje cicho; może dopisać pakiet do `profil_*.json`.

**Wejście dla AI (bez GUI):** `.\ai.bat test` — JSON na stdout, patrz `AGENTS.md`. `.\ai.bat add-url -Url https://... -Install`

## Dwie sekcje stanowiska

- **Biuro / projektowanie** — GstarCAD, Podpis GOV, Szafir KIR, HP Click, Tesseract
- **Programowanie i AI** — Git, GitHub CLI (`gh`), Python, Docker, Node, Cursor, Terminal
- **Dostęp zdalny** — Chrome Remote Desktop

## Cykl na czystej maszynie (teraz → +3 mc)

1. Dokończ pakiety z profilu (`start.bat`).
2. **Zrzut środowiska** → `srodowisko.json` + `python-requirements.txt` (przycisk w GUI albo `zrzut-srodowiska.ps1`). Commit do gita.
3. **Złoty obraz** na **drugi dysk** (USB/SSD, nigdy C:): przycisk albo `obraz-systemu.ps1 -BackupTarget E`. To `wbadmin` (Windows Backup), bez sysprep — sysprep psuje Docker i CAD.
4. Za kwartał: odzysk z Windows RE (Przywroc obraz systemu) → `git pull` → `winget upgrade --all` → pip z `python-requirements.txt`.

## GUI (`start.bat`)

| Widok | Co robi |
| --- | --- |
| **Konfiguracja** | Sekcje z `profil_*.json`, instalacja, WinUtil, zrzut JSON, obraz dysku |
| **Audyt** | `skanuj.ps1` — tweaki, AppX, usługi |
| **Skrypty i pliki** | Manifest pakietu |
| **Wykonywanie** | Log instalacji |

## Architektura

```
start.bat                 UAC + Bypass + s.ps1
s.ps1 / ui.xaml           panel Fluent
profil_*.json             PRZEPIS: co instalowac (sekcje biuro / kod)
srodowisko.json           ZRzut: co faktycznie jest (winget, pip, dodatki)
python-requirements.txt   pip freeze
zrzut-srodowiska.ps1      zbiera powyzsze
obraz-systemu.ps1         zloty obraz na USB/SSD
cli.ps1 / ai.bat          JSON CLI dla agentow (test, dump, fill)
AGENTS.md                 jak AI ma testowac i uzupelniac dane
ust_2.json                lista ID WinUtil
```

## Uruchomienie

1. Pakiet na cel; opcjonalnie `GstarCAD2022_PL_x64.exe` obok skryptow.
2. `start.bat` jako Administrator.
3. Zaznacz sekcje, zainstaluj; zrzut JSON; obraz na drugi dysk.

## Ograniczenia

- Obraz wymaga drugiego nosnika i miejsca (~dziesiatki GB).
- JSON nie zastapi obrazu sterownikow GPU / partycji recovery.
- `ust_2.json` to tablica ID WinUtil — sprawdz na aktualnym WinUtil `-Config`.
- WinUtil leci z internetu (`irm | iex`).
- Git/`gh` po instalacji bywaja niewidoczne az do **nowej konsoli** (PATH).

## Git

Trzymac w repo: skrypty, `profil_*.json`, `srodowisko.json`, `python-requirements.txt`.  
Nie wrzucac: `*.exe`, `raport_stanu_*.json`, `.cursor/`, same obrazy `wbadmin`.

To nie jest konkurencja dla [WinUtil](https://github.com/ChrisTitusTech/winutil) ani `winget configure`. To **przepis polskiego stanowiska CAD+AI + zrzut dla modeli + obraz dysku**.
