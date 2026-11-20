@echo off
rem ==================================================================
rem  g.bat - allenamento quotidiano (gabcode) (clang / clang++)
rem  Uso:  g.bat          -> C99  (gabcode.c)
rem        g.bat c89      -> C89  (gabcode.c)
rem        g.bat cpp      -> C++  (gabcode.cpp)
rem
rem  1. apre Notepad su un file vuoto
rem  2. intanto, se manca, scarica il compilatore (llvm-mingw: clang/clang++)
rem  3. premi un tasto -> compila -> esegue -> ricomincia
rem  Niente admin, niente installazioni: tutto in cartelle dell'utente.
rem ==================================================================
setlocal
set "MODE=%~1"
if "%MODE%"=="" set "MODE=c99"
set "DK=%LOCALAPPDATA%\llvm-mingw"
set "WORK=%USERPROFILE%\gabcode"

if /i "%MODE%"=="cpp" (set "SRC=gabcode.cpp") else (set "SRC=gabcode.c")

if not exist "%WORK%" mkdir "%WORK%"
cd /d "%WORK%"

rem --- foglio bianco: il file di ieri diventa old_gabcode.c ---
if exist "%SRC%" move /y "%SRC%" "old_%SRC%" >nul
type nul > "%SRC%"
start "" notepad "%SRC%"

rem --- compilatore: scaricato solo la prima volta su questo PC ---
if not exist "%DK%\bin\clang.exe" call :install
if not exist "%DK%\bin\clang.exe" (
    echo [ERRORE] Compilatore non disponibile. Rete o antivirus lo bloccano?
    pause
    exit /b 1
)
set "PATH=%DK%\bin;%PATH%"
echo Compilatore pronto: %DK%
echo Cartella di lavoro: %WORK%   (modalita' %MODE%)

:build
echo.
echo ---- Scrivi in Notepad, salva con Ctrl+S, poi premi un tasto qui ----
pause >nul
if /i "%MODE%"=="cpp" (
    clang++ -std=c++17 -Wall -Wextra -O2 -static "%SRC%" -o gabcode.exe
) else if /i "%MODE%"=="c89" (
    clang -std=c89 -pedantic -Wall -Wextra -O2 -static "%SRC%" -o gabcode.exe
) else (
    clang -std=c99 -Wall -Wextra -O2 -static "%SRC%" -o gabcode.exe
)
if errorlevel 1 (
    echo ==== Errori di compilazione: correggi in Notepad e riprova ====
    goto build
)
echo ==== Avvio gabcode.exe  [Ctrl+C per fermarlo, poi rispondi N] ====
gabcode.exe
echo ==== gabcode.exe terminato (codice %errorlevel%) ====
goto build

rem ------------------------------------------------------------------
:install
echo Scarico llvm-mingw (clang/clang++), solo la prima volta su questo PC...
echo (oltre 100 MB, puo' richiedere qualche minuto: intanto scrivi!)
set "URL="
for /f "usebackq delims=" %%u in (`powershell -NoProfile -Command "[Net.ServicePointManager]::SecurityProtocol='Tls12'; (Invoke-RestMethod 'https://api.github.com/repos/mstorsjo/llvm-mingw/releases/latest').assets | Where-Object { $_.name -like 'llvm-mingw-*-ucrt-x86_64.zip' } | Select-Object -First 1 -ExpandProperty browser_download_url"`) do set "URL=%%u"
if not defined URL (
    echo [ERRORE] Non trovo l'ultima versione di llvm-mingw su GitHub.
    exit /b 1
)
echo %URL%
curl -L --fail -o "%TEMP%\llvm-mingw.zip" "%URL%" || exit /b 1
echo Estraggo...
set "TMPX=%TEMP%\llvm-mingw-x"
if exist "%TMPX%" rmdir /s /q "%TMPX%"
mkdir "%TMPX%"
tar -xf "%TEMP%\llvm-mingw.zip" -C "%TMPX%" || exit /b 1
for /d %%d in ("%TMPX%\llvm-mingw-*") do move "%%d" "%DK%" >nul
rmdir /s /q "%TMPX%" >nul 2>&1
del "%TEMP%\llvm-mingw.zip" >nul 2>&1
exit /b 0
