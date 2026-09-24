# ConsisAI - krotki start (to wklejasz na www.redroad.pl/consisai jako plik).
# Uzycie:  irm https://www.redroad.pl/consisai | iex
# Sciaga bootstrap z GitHuba (wymaga PUBLICZNEGO repo).
$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
iex (Invoke-RestMethod "https://raw.githubusercontent.com/CONSIS-redroad/win11-workstation-setup/main/bootstrap.ps1")
