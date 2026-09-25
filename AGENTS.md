# AGENTS.md — jak AI ma uzywac tego repo

## Prosta idea (to caly produkt)

1. **`profil_*.json`** — przepis: co *ma* byc (winget, sekcje biuro/kod/AI).
2. **`srodowisko.json`** — zdjecie: co *jest* (`ai.bat dump`).
3. **Obraz dysku** — reset co kwartal ([OBRAZ-DYSKU.md](OBRAZ-DYSKU.md), `obraz-systemu.ps1`); potem `upgrade` + pip. Agent: `ai.bat image`, `ai.bat image-check` — **nie** wbadmin.

AI i czlowiek **edytuja JSON**, nie odtwarzaja klikow. Wejscie bez panelu: **`.\ai.bat`** (stdout = JSON). Nie testuj przez `start.bat` / `s.ps1`.

```text
.\ai.bat test
.\ai.bat dump
.\ai.bat diff
.\ai.bat fill -Section dev -WhatIf
.\ai.bat validate
```

- **`diff`** = zrzut vs przepis (czego brakuje w `profil_*.json`).
- **`fill` / `add-winget` / `add-url`** zapisuja profil — najpierw `-WhatIf`.
- Domyslny profil: `profil_msi.json`. Consis: `-Profile profil_consis.json`.
- Exit: **0** ok, **1** dane/pliki, **2** brak narzedzia. Pelna lista: `.\ai.bat help`.

Szczegoly faz (pip w przepisie, MCP): [ROADMAP.md](ROADMAP.md) — to **backlog**, nie warunek codziennej pracy.

---

## Rozszerzenia (maintainer, 2+ PC)

Nie zmieniaja prostej idei — pomagaja gdy masz **wiecej niz jedno stanowisko** (np. MSI dom + Consis biuro):

| Narzedzie | Po co |
| --- | --- |
| `maszyny/manifest.json` + zrzuty | referencje floty |
| `machines` | lista id maszyn |
| `compare` / `compare-fleet` | raport roznic; **`raport.dependencyGaps`** = gdzie brakuje bibliotek → apka ze drugiego PC moze nie dzialac |
| `pip-sync -Machine id` | plan pip wzgledem referencji; **`-Apply`** tylko po akceptacji |
| `py porownaj-maszyny.py`, `aktualizuj-pip.py` | to samo poza `ai.bat` |

Odswiezenie referencji: `dump` → skopiuj `srodowisko.json` do `maszyny/<snapshot>` z manifestu. **Korzen repo (`srodowisko.json`) = zrzut MSI**; Consis tylko w `maszyny/consis-b2bgdma.json`.

---

## Trzy tryby agenta (opcjonalnie osobne watki)

Jeden deliverable = jeden watek. Szczegoly: [AGENTS-analityk.md](AGENTS-analityk.md), [AGENTS-instalator.md](AGENTS-instalator.md), [AGENTS-audytor.md](AGENTS-audytor.md) — **skroty**, calosc i tak tutaj.

| Tryb | Robi | Nie robi |
| --- | --- | --- |
| **Patrz** | `diff`, `compare`, `list`, `machines` | zapis profilu, `pip-sync -Apply`, `upgrade` |
| **Zmien** | `fill`, `add-*`, `pip-sync`, `upgrade` | bez `-WhatIf` / planu |
| **Sprawdz** | `test`, `validate`, `scan` | commit `raport_stanu_*.json` |

---

## Pliki

| Plik | Rola |
| --- | --- |
| `profil_*.json` | przepis (nie mieszac CAD z pip) |
| `srodowisko.json`, `python-requirements.txt` | zrzut — `dump` |
| `mod-zrzut-dev.ps1` | pip + IDE, sekrety `***`, sciezki `%USERPROFILE%` |
| `maszyny/*.json` | opcjonalna flota |

Nie commituj: `*.exe`, `raport_stanu_*.json`, `.cursor/`, wbadmin, `.env`, tokeny.

## Prywatnosc (repo publiczne)

- Korzen: zrzut **MSI**. Flota: `maszyny/*.json` (inne PC).
- `dump` / `mod-zrzut-dev.ps1`: sekrety `***`; sciezki `%USERPROFILE%` / `%APPDATA%`.
- Przed `git add` przeszukaj diff: `api_key`, `token`, `password`, `ghp_`, `sk-`, surowe `mcp.json` z env.
- `pip-sync -Apply` wymaga `-ConfirmApply` (globalny pip). Plan bez Apply jest OK.

---

## Komendy (pelna tabela)

| Komenda | Zapisuje profil? |
| --- | --- |
| `help`, `test`, `status`, `validate`, `list`, `profile` | nie |
| `dump`, `scan` | zrzut / raport lokalny |
| `diff` | nie |
| `machines`, `compare`, `compare-fleet` | nie |
| `pip-sync` | plan; pip na dysku tylko `-Apply -ConfirmApply` |
| `fill`, `add-winget`, `add-url` | **tak** |
| `upgrade` | nie (siec) |
| `image`, `image-check` | nie (runbook / diagnostyka dyskow) |

Flagi: `-Profile`, `-Section`, `-Id`, `-Name`, `-Url`, `-Install`, `-WhatIf`, `-Other`, `-Machine`, `-OtherMachine`, `-Apply`, `-ConfirmApply`, `-Force`.
