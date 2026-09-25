# Roadmapa — win11 jako przepis stanowiska

**win11** stawia maszynę (winget, EXE z linku, tweaki, obraz dysku). **nunu** zostaje mózgiem (persony, graf, kontrakt MCP). Ten plik mówi, co jest zrobione, co dalej, i jak nie psuć drugiego komputera po obrazie.

**Dla AI:** codzienny kontrakt = [AGENTS.md](AGENTS.md) (prosta idea: przepis + dump + diff). **Ten plik** = co dopiero do zrobienia (pip w profilu, GUI…), nie trzeba go czytac przy kazdym `ai.bat test`.

Powiązane: [README.md](README.md) (cykl 3 miesiące), [SPOLECZNOSC.md](SPOLECZNOSC.md) (głosowanie na apki).

---

## Kontrakt CLI (obowiązkowy dla agentów)

Stdout = JSON (`ok`, `error`, listy). Exit **0** = sukces, **1** = błąd danych/plików, **2** = brak narzędzia. Domyślny przepis: `-Profile profil_msi.json`.

| Komenda | Po co | Zapisuje? |
| --- | --- | --- |
| `help` | katalog komend, flag, przykładów | nie |
| `test` | pliki, JSON, PATH (git/gh/python/node/docker + claude/cursor/gitleaks) | nie |
| `status` | narzędzia + czy są zrzuty (`srodowisko.json`) | nie |
| `dump` | zrzut faktu → `srodowisko.json` (winget, pip, Cursor/VS Code/Antigravity) | tak (zrzut, nie profil) |
| `diff` | winget ze zrzutu vs przepis | nie |
| `list` | pakiety z profilu (winget + DirectInstall) | nie |
| `profile` | cały JSON przepisu na stdout | nie |
| `validate` | `profil_msi.json`, `profil_consis.json`, `ust_2.json` | nie |
| `scan` | audyt tweaków → `raport_stanu_<PC>.json` (nie commituj) | raport |
| `fill -Section …` | dopisz brakujące ID winget do sekcji | **tak** — najpierw `-WhatIf` |
| `add-winget -Section … -Id …` | jedno ID winget | **tak** — najpierw `-WhatIf` |
| `add-url -Url …` | link ze strony / `Git.Git` / `.exe` | **tak** bez `-WhatIf`; `-Install` instaluje |
| `upgrade` | `winget upgrade --all` (sieć) | nie profil |

Flagi: `-Profile`, `-Section` (domyślnie `dev`), `-Id`, `-Name`, `-Url`, `-Install`, `-WhatIf`.

Szybki przebieg:

```text
.\ai.bat test
.\ai.bat status
.\ai.bat dump
.\ai.bat diff
.\ai.bat fill -Section ai-cli -WhatIf
.\ai.bat validate
.\ai.bat list
```

`-Section` zależy od profilu (nie mieszaj ID):

| Profil | Sekcje | CAD / pip |
| --- | --- | --- |
| `profil_msi.json` | `biuro`, `dev`, `ai-cli`, `zdalnie` | CAD w `biuro`; Python/Git w `dev`; CLI modeli w `ai-cli` |
| `profil_consis.json` | `wspolne`, `ai`, `bim`, `civil`, `kod`, `podpisy`, `zdalnie` | CAD w `bim`/`civil`; pip i Git w `kod` (nie w podpisach) |

---

## Stan na dziś (2026-09-25)

### Działa

| Obszar | Co jest |
| --- | --- |
| **Profile JSON** | `profil_consis.json` (role: architekt / civil / programista / pełne), `profil_msi.json` (biuro + dev + ai-cli) |
| **Podstawa** | Przeglądarki, komunikatory (Store), Steam/GOG/Epic, 7-Zip, PDF, Python, Grok Bot (DirectInstall z cursor.com) |
| **GUI** | Role, sekcje, WinUtil, audyt, z linku → winget/EXE, log instalacji |
| **Bezpieczeństwo instalacji** | Punkt przywracania przed instalacją profilu / z linku / WinUtil Auto; ostrzeżenie przy ≥3 pozycjach |
| **CLI** | pełny katalog w tabeli wyżej; `help` zwraca JSON (komendy + flagi + kody wyjścia); `validate` sprawdza **oba** profile |
| **Zrzut faktu** | `mod-zrzut-dev.ps1` + `zrzut-srodowiska.ps1` → `srodowisko.json` (pip, settings.json Cursor/VS Code/Antigravity z redakcją sekretów, rozszerzenia). `scan` dokłada to samo do `raport_stanu_*.json` |
| **Obraz** | `obraz-systemu.ps1` (wbadmin, drugi dysk, bez sysprep) |
| **Publikacja** | `bootstrap.ps1`, Issues pod głosowanie społeczności |
| **Skaner sekretów** | `Gitleaks.Gitleaks` w `profil_msi.json` (`dev`) i `profil_consis.json` (`kod`) — w PATH po instalacji; `test`/`status` raportują binarkę |

### Nadal słabe / braki

| Problem | Skutek |
| --- | --- |
| **`diff` / `fill` tylko winget** | Braki pip w przepisie nie widać w `ai.bat diff`; freeze nadal myli się z przepisem |
| **Brak sekcji pip w profilu** | LangGraph, FastMCP, LiteLLM, detect-secrets — ręcznie poza win11 |
| **Konflikt MCP 2.x** | `pip install` bez pinów może wziąć `mcp` 2.0 i złamać `from mcp.server.fastmcp import FastMCP` (patrz Faza B) |
| **Punkt przywracania** | Windows: max ~1 checkpoint / 24 h skryptem; czasem „sukces” bez nowego punktu — trzeba to komunikować w GUI |
| **Messenger / Store** | Część pakietów tylko ze Sklepu Microsoft (`9WZDNCRF0083` itd.) — zależy od regionu i winget |
| **Brak `srodowisko.json` w czystym clone** | `diff` zwraca pustkę i hint `ai.bat dump` — to jest OK, nie błąd |

---

## Wizja: jeden przepis, dwie warstwy

| Warstwa | Plik | Rola |
| --- | --- | --- |
| **Przepis** | `profil_*.json` | Co *ma* być (winget, DirectInstall, **docelowo pip**) |
| **Zdjęcie** | `srodowisko.json`, `python-requirements.txt` | Co *jest* (nie nadpisuje przepisu automatycznie) |

CLI trzyma tę granicę: `dump` pisze zdjęcie, `fill` / `add-winget` piszą przepis. Agent **najpierw** `diff` albo `-WhatIf`.

---

## Faza A — stabilność (zamknięta w dużej mierze)

- [x] Role + `Checked` z JSON (nie zaznaczać wszystkiego w sekcji ślepo)
- [x] Puste listy w JSON (`Winget` / `DirectInstalls` / brak `Roles`) — bez crashu GUI
- [x] `s.ps1` w UTF-8 z BOM (PowerShell 5.1 + polskie stringi)
- [x] `link-install.ps1`: sekcje bez `DirectInstalls` przy `add-url`
- [x] `ai.bat help` = JSON z pełną listą komend (w tym `add-winget`) i flag
- [x] `ai.bat validate` obejmuje `profil_consis.json`
- [ ] Test regresji: `profil_msi.json` + `profil_consis.json` w jednym smoke (automatyczny skrypt w repo — opcjonalnie)

---

## Faza B — przepis pip + CLI (priorytet)

### Winget (sekcja `kod` / `dev`)

- Git, GitHub CLI, Python 3.12, Docker Desktop, Node LTS, Windows Terminal, Cursor, Claude Code — **jest**
- Gitleaks (`Gitleaks.Gitleaks`) — **jest w przepisie**; instalacja na maszynie = `start.bat` albo ręczny winget (agent nie odpalaj GUI)
- LM Studio / Ollama — **wyłączone domyślnie** (`Checked: false`), dopóki ktoś nie włączy świadomie

### Pip — krótka lista w profilu (nowe pole JSON)

Propozycja struktury (do implementacji w `cli.ps1` + oba profile):

```json
"PythonPackages": [
  { "Name": "langgraph", "Spec": "langgraph>=0.2,<1" },
  { "Name": "langgraph-checkpoint-sqlite", "Spec": "langgraph-checkpoint-sqlite" },
  { "Name": "fastmcp", "Spec": "fastmcp" },
  { "Name": "mcp-sdk-pin", "Spec": "mcp>=1.8,<2", "Note": "FastMCP / import fastmcp wymaga MCP 1.x" },
  { "Name": "litellm", "Spec": "litellm" },
  { "Name": "detect-secrets", "Spec": "detect-secrets" }
]
```

Pole w sekcji `dev` / `kod` — **nie** w `biuro` / `bim` / `podpisy`. GUI dziś ignoruje nieznane pola; `fill`/`Save-Profile` muszą je zachować.

**Pin MCP (ważne):** od wydania **mcp 2.0** moduł `mcp.server.fastmcp` zniknął (rename na `MCPServer`). Dopóki stack opiera się na FastMCP 1.x-style importach, w przepisie obowiązkowo **`mcp>=1.x,<2`**. Konflikt z LiteLLM (ciągnie inne wersje) ma być **widoczny w `diff`**, nie cichym downgrade.

### Zachowanie CLI (docelowe — jeszcze nie zrobione)

1. `ai.bat test` — PATH: `git`, `gh`, `python`, `docker`, `gitleaks` (gdy w profilu) — **rdzeń już raportuje**; pip-check później.
2. `ai.bat diff` — braki **winget + pip** względem `srodowisko.json` / `pip list`.
3. `ai.bat fill-pip` (lub rozszerzenie `fill`) — dopisuje braki do profilu; **`-WhatIf` przed zapisem**.
4. `ai.bat install-pip -WhatIf` — suchy przebieg `pip install` z przepisu (bez GUI).
5. Po obrazie dysku: **`winget` z profilu → krótka lista pip → dopiero opcjonalnie pełny freeze** do archiwum.

**Kryterium „Faza B done”:**

- oba profile mają `PythonPackages` w `dev`/`kod`;
- `ai.bat diff` zwraca osobne listy `missingWinget` i `missingPip`;
- `ai.bat help` zawiera `install-pip` (albo równoważnik);
- na czystym Python 3.12 + profil: `python -c "from fastmcp import FastMCP"`, `import langgraph`, `import litellm`, `gitleaks version`;
- `fill` z `-WhatIf` nie kasuje pola `PythonPackages` przy zapisie winget.

---

## Faza C — GUI i obraz (dopracowanie)

- [x] Punkt przywracania przed zmianami (reguła produktu)
- [ ] W logu GUI: jasny komunikat gdy checkpoint zablokowany (24 h / wyłączone przywracanie) — zgodnie z [Microsoft Checkpoint-Computer](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/checkpoint-computer)
- [ ] Instalacja winget: `--disable-interactivity` wszędzie jak w `link-install.ps1`
- [ ] Opcja „tylko zaznaczone z jednej sekcji” (mniej przypadkowych masowych instalacji)
- [ ] Wersjonowany URL Grok Bot (obecnie pin `0.58.0`) — skrypt „odśwież link ze strony” albo pole `LatestFromPage` w JSON

To faza **GUI**. Agent jej nie zamyka przez `start.bat`.

---

## Faza D — drugi komputer i kwartał

Cykl z README (bez zmian merytorycznych):

1. Człowiek: `start.bat` / profil → instalacja. Agent: `dump` → commit JSON (gdy użytkownik każe).
2. Złoty obraz na **drugi dysk** (`obraz-systemu.ps1`).
3. Za ~3 miesiące: restore z Windows RE → `git pull` → `ai.bat upgrade` → `pip install` **z krótkiej listy przepisu** (nie ślepo z całego freeze).

Checklist drugiego PC:

- [ ] Ten sam `profil_*.json` + ta sama rola
- [ ] CAD: lokalne EXE / OEM w folderze paczki
- [ ] Bez sekretów w JSON (MCP, API — vault / nunu, nie profil)
- [ ] Po restore: `ai.bat test` → `dump` → `diff` (nie GUI)

---

## Faza E — społeczność i przepis

- Głosy 👍 w Issues → propozycje do `profil_consis.json` ([SPOLECZNOSC.md](SPOLECZNOSC.md))
- Co kwartał: przegląd winget ID (Messenger, WhatsApp Store), wersje Grok Bot, Epic/Steam
- **Nie w repo:** `*.exe`, klucze CAD, `raport_stanu_*.json`, obrazy wbadmin; zrzut z obcej maszyny tylko po `dump` + przeglądz diff (sekrety, ścieżki)

---

## Poza win11 (świadomie nie tu)

| Temat | Gdzie |
| --- | --- |
| Proces MCP, router `:4000` | Host / nunu |
| `nunu.toml`, vault kluczy | Lokalnie, poza gitem |
| Pełna automatyzacja BIM | Repo projektów, nie ten pakiet |
| Persony, attach, heal | `nunu/` — nie kopiować kanonów tutaj |

---

## Kolejność prac (najbliższe commity)

1. ~~Gitleaks w winget~~ **zrobione** (`dev` / `kod`).
2. **JSON:** pole `PythonPackages` w sekcji `dev`/`kod` (oba profile).
3. **`cli.ps1`:** `diff`/`fill` uwzględnia pip; raport konfliktu wersji `mcp`; `Save-Profile` nie gubi nowych pól.
4. **`ai.bat install-pip`** (lub podkomenda) z `-WhatIf`; wpis w `help`.
5. **Test:** `ai.bat test` + `validate` + ręczny import FastMCP/langgraph/litellm → wpis „Faza B done”.
6. Drobne GUI: komunikat 24 h restore, odświeżanie linku Grok Bot.

---

## Źródła (web / praktyka)

- MCP SDK 2.0 breaking change — pin `mcp<2` dla FastMCP: [modelcontextprotocol/python-sdk](https://github.com/modelcontextprotocol/python-sdk) / dyskusje migracji 2026-07.
- Gitleaks: preferowany **`Gitleaks.Gitleaks`** w winget na stacji; w CI często binarka z GitHub Releases zamiast starego action.
- Restore point: tylko **Windows PowerShell 5.1** + admin; limit 24 h — [Checkpoint-Computer](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/checkpoint-computer).
- Idempotentny setup (restore → winget skip if installed): inspiracja [windows-setup.ps1 gist](https://gist.github.com/lugnut42/18a030d917defe66a6e8cc79a8572347).
