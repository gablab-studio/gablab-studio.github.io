@echo off
rem ==================================================================
rem  toolchain.bat - trova o scarica llvm-mingw (clang / clang++)
rem
rem  Uso (da un altro .bat):   call toolchain.bat
rem  Al ritorno:  DK   = cartella della toolchain
rem               PATH = con %DK%\bin davanti
rem               errorlevel 1 se qualcosa e' andato storto
rem
rem  Niente admin: tutto finisce in %LOCALAPPDATA%\llvm-mingw-*
rem ==================================================================
set "DK="
call :tc_find
if not defined DK (
    call :tc_install
    call :tc_find
)
if not defined DK (
    echo [ERRORE] Toolchain non disponibile. Rete o antivirus la bloccano?
    exit /b 1
)
set "PATH=%DK%\bin;%PATH%"
exit /b 0

rem ------------------------------------------------------------------
:tc_find
set "DK="
for /d %%d in ("%LOCALAPPDATA%\llvm-mingw-*") do if exist "%%d\bin\clang.exe" set "DK=%%d"
exit /b 0

:tc_install
echo Scarico llvm-mingw (clang/clang++), solo la prima volta su questo PC...
echo (oltre 100 MB, puo' richiedere qualche minuto)
set "TC_URL="
for /f "usebackq delims=" %%u in (`powershell -NoProfile -Command "[Net.ServicePointManager]::SecurityProtocol='Tls12'; (Invoke-RestMethod 'https://api.github.com/repos/mstorsjo/llvm-mingw/releases/latest').assets | Where-Object { $_.name -like 'llvm-mingw-*-ucrt-x86_64.zip' } | Select-Object -First 1 -ExpandProperty browser_download_url"`) do set "TC_URL=%%u"
if not defined TC_URL (
    echo [ERRORE] Non trovo l'ultima versione di llvm-mingw su GitHub.
    exit /b 1
)
echo %TC_URL%
curl -L --fail -o "%TEMP%\llvm-mingw.zip" "%TC_URL%" || exit /b 1
echo Estraggo in %LOCALAPPDATA% ...
rem estrazione diretta, senza spostare cartelle (l'antivirus le blocca)
tar -xf "%TEMP%\llvm-mingw.zip" -C "%LOCALAPPDATA%" || exit /b 1
del "%TEMP%\llvm-mingw.zip" >nul 2>&1
exit /b 0
