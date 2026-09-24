@echo off
REM AI CLI - bez UAC, bez GUI, JSON na stdout. Dla Cursor / Claude Code / skryptow.
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0cli.ps1" %*
