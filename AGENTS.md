# AGENTS.md — jak AI ma uzywac tego repo

To stanowisko Windows (CAD + kod). **Zrodlem prawdy jest JSON**, nie klikany GUI.

## Szybki start (CLI)

Z katalogu pakietu, bez GUI:

```text
.\ai.bat test
.\ai.bat status
.\ai.bat dump
.\ai.bat diff
.\ai.bat fill -Section ai-cli
.\ai.bat add-winget -Section ai-cli -Id Anthropic.ClaudeCode -Name "Claude Code"
```

- Stdout = JSON (`ok`, `error`, listy).
- Exit 0 = sukces, 1 = blad danych/plikow, 2 = brak narzedzia.
- Nie odpalaj `start.bat` / `s.ps1` do testow — to WPF + Admin.
- `fill` i `add-winget` **zapisują** `profil_*.json`. Najpierw `diff` albo `fill -WhatIf`.

## Co wolno zmieniac

| Plik | Rola |
| --- | --- |
| `profil_msi.json` | Przepis: sekcje `biuro`, `dev`, `ai-cli`, `zdalnie` |
| `srodowisko.json` | Zrzut faktu (winget, pip, npm, dodatki Cursor, Docker) — regeneruj `dump` |
| `python-requirements.txt` | `pip freeze` |
| `ust_2.json` | ID WinUtil |

Nie commituj: `*.exe`, `raport_stanu_*.json`, katalogu `.cursor/`, obrazow `wbadmin`, `.env`, kluczy API, plikow z haslami/tokenami.

## Prywatnosc (repo publiczne)

- `dump` zapisuje tylko listy pakietow i wersji — **nie** powinien zawierac sekretow. Przed `git add` przeszukaj diff pod katem: `api_key`, `token`, `password`, `ghp_`, `sk-`, sciezki z wrazliwymi plikami.
- Nie dopisuj do JSON adresow e-mail, numerow telefonow ani danych klientow biura.
- Profile osobiste w przyszlosci: szyfrowanie haslem / konto Google / prywatne repo — na razie pelny zrzut MSI moze byc w tym repozytorium (jeden maintainer).

## Typowy przebieg agenta

1. `.\ai.bat test` — czy git/gh/python/json zyja.
2. `.\ai.bat dump` — zbierz biblioteki i dodatki.
3. `.\ai.bat diff` — czego nie ma w profilu.
4. Uzupelnij profil (`fill` albo reczna edycja JSON) — **to jest kopia srodowiska**.
5. `.\ai.bat validate` + `list`.

Nowy pakiet z linku ze strony (czlowiek w GUI: zakladka **Z linku**):

```text
.\ai.bat add-url -Url "https://git-scm.com" -Section dev
.\ai.bat add-url -Url "https://..." -Section biuro -Install
.\ai.bat add-url -Url "Git.Git" -WhatIf
```

Upgrade po wczytaniu zlotego obrazu dysku: `.\ai.bat upgrade` (siec).

## Sekcje profilu

- `biuro` — CAD, podpisy, ploter (nie mieszac z Pythonem).
- `dev` — Git, gh, Python, Docker, Node, Cursor.
- `ai-cli` — narzedzia liniowe dla modeli (Claude Code itd.).
- `zdalnie` — Chrome Remote Desktop.

Nowe ID winget: `add-winget -Section ... -Id Vendor.Package -Name "Czytelna nazwa"`.
