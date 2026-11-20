@echo off
rem ==================================================================
rem  debugger.bat - trova o scarica RAD Debugger (raddbg)
rem
rem  Uso (da un altro .bat):   call debugger.bat
rem  Al ritorno:  RDBG = percorso completo di raddbg.exe
rem               errorlevel 1 se qualcosa e' andato storto
rem
rem  Niente admin: tutto finisce in %LOCALAPPDATA%\raddbg
rem ==================================================================
set "RDBG="
call :db_find
if not defined RDBG (
    call :db_install
    call :db_find
)
if not defined RDBG (
    echo [ERRORE] Debugger non disponibile. Rete o antivirus lo bloccano?
    exit /b 1
)
exit /b 0

rem ------------------------------------------------------------------
:db_find
set "RDBG="
if exist "%LOCALAPPDATA%\raddbg" for /r "%LOCALAPPDATA%\raddbg" %%f in (raddbg.exe) do if exist "%%f" set "RDBG=%%f"
exit /b 0

:db_install
echo Scarico RAD Debugger, solo la prima volta su questo PC...
set "DB_URL="
rem le release sono "alpha": prendo la piu' recente che contiene raddbg*.zip
for /f "usebackq delims=" %%u in (`powershell -NoProfile -Command "[Net.ServicePointManager]::SecurityProtocol='Tls12'; $r = Invoke-RestMethod 'https://api.github.com/repos/EpicGamesExt/raddebugger/releases?per_page=15'; foreach ($x in $r) { $a = $x.assets | Where-Object { $_.name -like 'raddbg*.zip' }; if ($a) { $b = $a | Where-Object { $_.name -eq 'raddbg.zip' } | Select-Object -First 1; if (-not $b) { $b = $a | Select-Object -First 1 }; $b.browser_download_url; break } }"`) do set "DB_URL=%%u"
if not defined DB_URL (
    echo [ERRORE] Non trovo una release di RAD Debugger su GitHub.
    exit /b 1
)
echo %DB_URL%
curl -L --fail -o "%TEMP%\raddbg.zip" "%DB_URL%" || exit /b 1
if not exist "%LOCALAPPDATA%\raddbg" mkdir "%LOCALAPPDATA%\raddbg"
echo Estraggo in %LOCALAPPDATA%\raddbg ...
tar -xf "%TEMP%\raddbg.zip" -C "%LOCALAPPDATA%\raddbg" || exit /b 1
del "%TEMP%\raddbg.zip" >nul 2>&1
exit /b 0
