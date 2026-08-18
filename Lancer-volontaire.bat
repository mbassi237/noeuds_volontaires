@echo off
REM ============================================================
REM  Lanceur pour volontaires Windows.
REM
REM  Double-cliquez simplement sur ce fichier.
REM
REM  Il demande lui-meme les droits administrateur, contourne le
REM  blocage des scripts PowerShell, et lance talinet_volunteer.ps1
REM  qui se trouve dans le meme dossier.
REM ============================================================
title Installation du volontaire

REM --- Sommes-nous administrateur ? ---
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo   Droits administrateur necessaires.
    echo   Une fenetre de confirmation va s'ouvrir : repondez Oui.
    echo.
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

cd /d "%~dp0"

if not exist "talinet_volunteer.ps1" (
    echo.
    echo   [ECHEC] Le fichier talinet_volunteer.ps1 est introuvable.
    echo   Il doit se trouver dans le meme dossier que ce lanceur.
    echo.
    pause
    exit /b 1
)

REM --- Deblocage : Windows marque les fichiers venus d'Internet ---
powershell -NoProfile -Command "Get-ChildItem -Path '.' -Filter '*.ps1' | Unblock-File -ErrorAction SilentlyContinue"

echo.
echo   Lancement de l'installation...
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File ".\talinet_volunteer.ps1"

echo.
echo   Fenetre maintenue ouverte. Fermez-la quand vous le souhaitez.
pause
