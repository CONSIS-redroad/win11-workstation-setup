# ConsisAI - stanowisko projektanta i kodu

Paczka i panel dla **biur projektowych**, ktore juz mieszaja CAD z AI. Nie musisz byc programista, zeby kliknac role Architekt i dostac 7-Zip, PDF, Pythona i Claude'a. Jesli automatyzujesz BIM - dokladasz Git i Dockera.

## Po co to jest publiczne

Zeby **spolecznosc projektantow glosowala** (emotka 👍, bez Gita):

- jakie apki realnie stoja na stanowisku (Revit, IronCAD, GstarCAD, Claude, …)
- co w Windows 11 przeszkadza przy modelu
- jak ktoś w ogole wpuszcza AI do projektu

Szablony: **[SPOLECZNOSC.md](SPOLECZNOSC.md)**. Najczesciej glosowane rzeczy wchodza do zalecen w `profil_consis.json`.

To tez **wizytowka**: projektant drogowy, niedoszly programista, ktory ostatnio siedzi po 10 godzin w kodzie, nie przed CADem. Consis / [Redroad](https://www.redroad.pl). Chodzi o to, zeby kolegów po fachu wprowadzic w programowanie i AI, zanim zmiana nawykow ich wyprzedzi.

**AI (bez GUI):** **[AGENTS.md](AGENTS.md)** — przepis JSON + zrzut + `ai.bat`. Backlog: [ROADMAP.md](ROADMAP.md).

## Start (gdy repo publiczne)

Nie `winget https://...`. Jak Chris Titus, tylko paczka z panelem:

```powershell
irm https://raw.githubusercontent.com/CONSIS-redroad/win11-workstation-setup/main/bootstrap.ps1 | iex
```

Pozniej: `irm https://www.redroad.pl/consisai | iex` (ten sam skrypt na stronie).


## Role w panelu

| Rola | Co zaznacza |
| --- | --- |
| Architekt / BIM | podstawa + AI + Revit/AutoCAD/IronCAD + podpisy |
| Projektant drogowy / civil | podstawa + AI + GstarCAD/ploter/OCR + podpisy |
| Programista | podstawa + AI + Git/Docker/Node |
| Pelne stanowisko Consis | wszystko |

CAD z Autodesk/IronCAD **nie jest w winget** jak 7-Zip. Wrzuc instalator do folderu paczki albo wklej link w zakladce **Z linku**.

## Po co to jest (JSON + obraz)

Dwa byty, których nie wolno mylić:

| Warstwa | Co to jest | Po co |
| --- | --- | --- |
| **JSON w gicie** | Przepis środowiska | AI i Ty **edytujecie plik** (pakiety, pip, dodatki Cursor). To kopia stanowiska, którą da się czytać i poprawiać bez klików. |
| **Obraz dysku** | Zdjęcie czystego Windows (teraz, 2–3 dni po instalacji) | Za 3 miesiące **wczytujesz obraz**, nie stawiasz systemu od zera. Potem tylko `winget upgrade --all` + ewentualnie `pip install -r python-requirements.txt`. |

WinUtil, GstarCAD i GUI są narzędziami. **Wartością repo jest: środowisko jako JSON + złoty obraz, nie kolejny debloat.**

Modele AI łatwo zjadają JSON (biblioteki, rozszerzenia, ID winget). Nie lubią odtwarzać klikanej konfiguracji z pamięci. Dlatego zrzut idzie do `srodowisko.json`, a świadomy przepis do `profil_*.json`.

**Zakładka „Z linku”:** wklejasz URL ze strony (albo `Git.Git`, albo bezpośredni `.exe`). Program szuka w winget i instaluje cicho; może dopisać pakiet do `profil_*.json`.

**Wejście dla AI (bez GUI):** `.\ai.bat help` potem `.\ai.bat test` — JSON na stdout, patrz `AGENTS.md`. Nie `start.bat`. `.\ai.bat add-url -Url https://... -WhatIf`

## Dwie sekcje stanowiska

- **Architekt / BIM** — Revit, AutoCAD, IronCAD (instalatory lokalne) + PDF/Python/AI
- **Civil** — GstarCAD, HP Click, Tesseract, podpisy
- **Podstawa** — przeglądarki (Chrome/Firefox/Opera), WhatsApp/Telegram/Messenger, Steam/GOG/Epic, 7-Zip, PDF, Python, Grok Bot
- **AI** — Claude Code, Cursor, opcjonalnie Gemini CLI

## Cykl na czystej maszynie (teraz → +3 mc)

1. Dokończ pakiety z profilu (`start.bat`).
2. **Zrzut środowiska** → `srodowisko.json` + `python-requirements.txt` (przycisk w GUI albo `zrzut-srodowiska.ps1`). Commit do gita.
3. **Złoty obraz** na **drugi dysk** (USB/SSD, nigdy C:): przycisk albo `obraz-systemu.ps1 -BackupTarget E`. To `wbadmin` (Windows Backup), bez sysprep — sysprep psuje Docker i CAD.
4. Za kwartał: odzysk z Windows RE → `git pull` → `ai.bat upgrade` → pip. Szczegoly: **[OBRAZ-DYSKU.md](OBRAZ-DYSKU.md)** | `.\ai.bat image`.

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
srodowisko.json           ZRzut: co faktycznie jest (winget, pip, ustawienia IDE)
python-requirements.txt   pip freeze
mod-zrzut-dev.ps1         pip + Cursor/VS Code/Antigravity (bez sekretow)
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

Trzymac w repo: skrypty, `profil_*.json`, `srodowisko.json`, `python-requirements.txt`, `mod-zrzut-dev.ps1`, `ROADMAP.md`.  
Nie wrzucac: `*.exe`, `raport_stanu_*.json`, `.cursor/`, same obrazy `wbadmin`, pliki `.env`, klucze API, hasla, eksporty z tokenami OAuth.

**Co jest w zrzucie:** publiczne ID pakietow (winget, pip, npm, rozszerzenia IDE), wersje, nazwa komputera — **bez** sekretow w ustawieniach (redakcja w `mod-zrzut-dev.ps1`) i **bez** pelnych sciezek uzytkownika (placeholdery `%USERPROFILE%` / `%APPDATA%`). Po `ai.bat dump` przed commitem sprawdz diff; agentowi: [AGENTS.md](AGENTS.md) (prywatnosc).

### Prywatnosc profili (stan teraz i plan)

Repo jest **jawne** (spolecznosc + bootstrap `irm`). Pelny zrzut stanowiska MSI (`srodowisko.json`) trafia do gita jako odtwarzalna kopia — na razie glownie maintainer, po przegladzie diffa.

**W przyszlosci** (gdy wiecej osob bedzie trzymac wlasne przepisy):

- profile **prywatne** lub **zaszyfrowane haslem** (eksport/import poza publicznym JSON),
- **powiazanie z kontem Google** (lub innym IdP) — profil w chmurze uzytkownika, nie w publicznym repo,
- ewentualnie **osobne repo prywatne** na zrzut maszyny, a w publicznym tylko szablony `profil_consis.json` / glosowanie spolecznosci.

Do tego czasu: nie commituj `.env`, tokenow CI, eksportow podpisow kwalifikowanych ani lokalnych `raport_stanu_*.json` bez redakcji.

To nie jest konkurencja dla [WinUtil](https://github.com/ChrisTitusTech/winutil). To **zalecenia polskiego biura projektowego + glos spolecznosci + most do AI**.
