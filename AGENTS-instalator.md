# Agent: zmien (skrot)

Pelna zasada: [AGENTS.md](AGENTS.md) — petla `dump` → `diff` → `fill -WhatIf`.

**Ten watek:** po akceptacji planu z watku „patrz” — `fill`, `add-winget`, `add-url`, `pip-sync`, `upgrade`.

**Zasada:** zawsze `-WhatIf` lub plan `pip-sync` bez `-Apply` pierwszy. Apply: `-Apply -ConfirmApply`.

**Nie:** analiza floty od zera w tym samym watku co `-Apply`.
