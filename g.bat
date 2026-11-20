@echo off
rem ==================================================================
rem  g.bat - allenamento quotidiano (gabcode) con clang / clang++
rem  Uso:  g            -> C99  (gabcode.c)
rem        g c89        -> C89  (gabcode.c)
rem        g cpp        -> C++  (gabcode.cpp)
rem        g canc       -> cancella tutto (cartella, toolchain, g.bat)
rem
rem  Nel ciclo:  Invio = compila ed esegui
rem              canc  = cancella tutto
rem              esci  = chiudi lo script
rem ==================================================================
setlocal
set "MODE=%~1"
if "%MODE%"=="" set "MODE=c99"
set "WORK=%USERPROFILE%\gabcode"
set "INLOOP="

if /i "%MODE%"=="canc" goto canc

if /i "%MODE%"=="cpp" (set "SRC=gabcode.cpp") else (set "SRC=gabcode.c")

if not exist "%WORK%" mkdir "%WORK%"
cd /d "%WORK%"

rem --- foglio bianco: il file di ieri diventa old_gabcode.c ---
if exist "%SRC%" move /y "%SRC%" "old_%SRC%" >nul
type nul > "%SRC%"
start "" notepad "%SRC%"

rem --- compilatore: scaricato solo la prima volta su questo PC ---
call :find
if not defined DK (
    call :install
    call :find
)
if not defined DK (
    echo [ERRORE] Compilatore non disponibile. Rete o antivirus lo bloccano?
    pause
    exit /b 1
)
set "PATH=%DK%\bin;%PATH%"
echo Compilatore pronto: %DK%
echo Cartella di lavoro: %WORK%   (modalita' %MODE%)
set "INLOOP=1"

:build
echo.
echo ---- Salva con Ctrl+S, poi:  [Invio] compila   canc = cancella tutto   esci = chiudi ----
set "CMD="
set /p "CMD=> "
if /i "%CMD%"=="canc" goto canc
if /i "%CMD%"=="esci" exit /b 0
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
echo.
echo ==== gabcode.exe terminato (codice %errorlevel%) ====
goto build

rem ------------------------------------------------------------------
:canc
echo.
echo Verranno cancellati DEFINITIVAMENTE (niente Cestino):
echo   - la cartella %WORK% con tutto il contenuto
echo   - la toolchain in %LOCALAPPDATA%\llvm-mingw-*
echo   - questo script: %~f0
echo Chiudi prima Notepad se ha modifiche non salvate che ti servono.
choice /c SN /m "Confermi"
if errorlevel 2 (
    echo Annullato, non ho cancellato niente.
    if defined INLOOP goto build
    exit /b 0
)
cd /d "%USERPROFILE%"
if exist "%WORK%" rmdir /s /q "%WORK%"
for /d %%d in ("%LOCALAPPDATA%\llvm-mingw-*") do rmdir /s /q "%%d"
if exist "%TEMP%\llvm-mingw-x" rmdir /s /q "%TEMP%\llvm-mingw-x" >nul 2>&1
del "%TEMP%\llvm-mingw.zip" >nul 2>&1
if exist "%WORK%" echo [!] Non sono riuscito a cancellare %WORK% del tutto (file aperto?).
for /d %%d in ("%LOCALAPPDATA%\llvm-mingw-*") do echo [!] Non sono riuscito a cancellare %%d del tutto.
echo Pulizia completata. Cancello anche g.bat e chiudo.
rem l'ultima riga cancella lo script stesso mentre termina
(goto) 2>nul & del "%~f0"

rem ------------------------------------------------------------------
:find
rem cerca una cartella llvm-mingw-*-ucrt-x86_64 gia' estratta
set "DK="
for /d %%d in ("%LOCALAPPDATA%\llvm-mingw-*") do if exist "%%d\bin\clang.exe" set "DK=%%d"
exit /b 0

:install
echo Scarico llvm-mingw (clang/clang++), solo la prima volta su questo PC...
echo (oltre 100 MB, puo' richiedere qualche minuto: intanto scrivi!)
rem resti di un tentativo precedente
if exist "%TEMP%\llvm-mingw-x" rmdir /s /q "%TEMP%\llvm-mingw-x" >nul 2>&1
set "URL="
for /f "usebackq delims=" %%u in (`powershell -NoProfile -Command "[Net.ServicePointManager]::SecurityProtocol='Tls12'; (Invoke-RestMethod 'https://api.github.com/repos/mstorsjo/llvm-mingw/releases/latest').assets | Where-Object { $_.name -like 'llvm-mingw-*-ucrt-x86_64.zip' } | Select-Object -First 1 -ExpandProperty browser_download_url"`) do set "URL=%%u"
if not defined URL (
    echo [ERRORE] Non trovo l'ultima versione di llvm-mingw su GitHub.
    exit /b 1
)
echo %URL%
curl -L --fail -o "%TEMP%\llvm-mingw.zip" "%URL%" || exit /b 1
echo Estraggo in %LOCALAPPDATA% ...
rem estrazione diretta, senza spostare cartelle (l'antivirus le blocca)
tar -xf "%TEMP%\llvm-mingw.zip" -C "%LOCALAPPDATA%" || exit /b 1
del "%TEMP%\llvm-mingw.zip" >nul 2>&1
exit /b 0
