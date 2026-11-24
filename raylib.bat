@echo off
rem ==================================================================
rem  raylib.bat - trova o scarica raylib (pacchetto win64 mingw-w64)
rem
rem  Uso (da un altro .bat):   call raylib.bat
rem  Al ritorno:  RL = cartella di raylib (con include\ e lib\)
rem               errorlevel 1 se qualcosa e' andato storto
rem
rem  Niente admin: tutto finisce in %LOCALAPPDATA%\raylib-*
rem ==================================================================
set "RL="
call :rl_find
if not defined RL (
    call :rl_install
    call :rl_find
)
if not defined RL (
    echo [ERRORE] raylib non disponibile. Rete o antivirus la bloccano?
    exit /b 1
)
exit /b 0

rem ------------------------------------------------------------------
:rl_find
set "RL="
for /d %%d in ("%LOCALAPPDATA%\raylib-*") do if exist "%%d\include\raylib.h" set "RL=%%d"
exit /b 0

:rl_install
echo Scarico raylib, solo la prima volta su questo PC...
set "RL_URL="
for /f "usebackq delims=" %%u in (`powershell -NoProfile -Command "[Net.ServicePointManager]::SecurityProtocol='Tls12'; (Invoke-RestMethod 'https://api.github.com/repos/raysan5/raylib/releases/latest').assets | Where-Object { $_.name -like '*_win64_mingw-w64.zip' } | Select-Object -First 1 -ExpandProperty browser_download_url"`) do set "RL_URL=%%u"
if not defined RL_URL (
    echo [ERRORE] Non trovo l'ultima versione di raylib su GitHub.
    exit /b 1
)
echo %RL_URL%
curl -L --fail -o "%TEMP%\raylib.zip" "%RL_URL%" || exit /b 1
echo Estraggo in %LOCALAPPDATA% ...
tar -xf "%TEMP%\raylib.zip" -C "%LOCALAPPDATA%" || exit /b 1
del "%TEMP%\raylib.zip" >nul 2>&1
exit /b 0
