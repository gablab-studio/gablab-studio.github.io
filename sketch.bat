@echo off
rem ==================================================================
rem  sketch.bat - foglio di allenamento quotidiano (clang / clang++)
rem  Uso:  sketch          -> C99  (gabcode.c)
rem        sketch c89      -> C89  (gabcode.c)
rem        sketch cpp      -> C++  (gabcode.cpp)
rem        sketch canc     -> cancella tutto (vedi sotto)
rem
rem  Nel ciclo:  Invio   = compila ed esegui
rem              persist = salva lo sketch come progetto vero
rem              canc    = cancella gabcode, toolchain, build dei progetti, sketch.bat
rem              esci    = chiudi
rem
rem  La toolchain la gestisce toolchain.bat (repo separata).
rem ==================================================================
setlocal
set "TCURL=https://gablab-studio.github.io/toolchain/toolchain.bat"
set "MODE=%~1"
if "%MODE%"=="" set "MODE=c99"
set "WORK=%USERPROFILE%\gabcode"
set "INLOOP="

if /i "%MODE%"=="canc" goto canc

if /i "%MODE%"=="cpp" (
    set "SRC=gabcode.cpp"
    set "CC=clang++"
    set "STDFLAG=-std=c++17"
    set "UNITY=unity.cpp"
    set "CSTD=c99"
) else if /i "%MODE%"=="c89" (
    set "SRC=gabcode.c"
    set "CC=clang"
    set "STDFLAG=-std=c89 -pedantic"
    set "UNITY=unity.c"
    set "CSTD=c89"
) else (
    set "SRC=gabcode.c"
    set "CC=clang"
    set "STDFLAG=-std=c99"
    set "UNITY=unity.c"
    set "CSTD=c99"
)

if not exist "%WORK%" mkdir "%WORK%"
cd /d "%WORK%"

rem --- foglio bianco: il file di ieri diventa old_gabcode.c ---
if exist "%SRC%" move /y "%SRC%" "old_%SRC%" >nul
type nul > "%SRC%"
start "" notepad "%SRC%"

rem --- compilatore: se manca, lo procura toolchain.bat ---
call :find
if not defined DK call :gettc
if not defined DK (
    echo [ERRORE] Compilatore non disponibile.
    pause
    exit /b 1
)
set "PATH=%DK%\bin;%PATH%"
echo Compilatore pronto: %DK%
echo Cartella di lavoro: %WORK%   (modalita' %MODE%)
set "INLOOP=1"

:build
echo.
echo ---- Salva con Ctrl+S, poi:  [Invio] compila   persist   canc   esci ----
set "SCELTA="
set /p "SCELTA=> "
if /i "%SCELTA%"=="persist" goto persist
if /i "%SCELTA%"=="canc" goto canc
if /i "%SCELTA%"=="esci" exit /b 0
%CC% %STDFLAG% -Wall -Wextra -O2 -static "%SRC%" -o gabcode.exe
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
:persist
echo.
set "PNAME="
set /p "PNAME=Nome del progetto (senza spazi, Invio per annullare): "
if not defined PNAME (
    echo Annullato.
    goto build
)
if not "%PNAME: =%"=="%PNAME%" (
    echo Niente spazi nel nome: usa - oppure _
    goto build
)
call :projroot
if not defined ROOT (
    echo [ERRORE] Non riesco a creare la cartella dei progetti.
    goto build
)
set "PDIR=%ROOT%\%PNAME%"
if exist "%PDIR%" (
    echo Esiste gia': %PDIR%
    goto build
)
mkdir "%PDIR%\src" "%PDIR%\build" "%PDIR%\.vscode"
move /y "%WORK%\%SRC%" "%PDIR%\src\%UNITY%" >nul
if exist "%WORK%\gabcode.exe" del "%WORK%\gabcode.exe"
call :write_build
call :write_vscode
>"%PDIR%\.gitignore" echo build/
echo.
echo ==== Progetto creato: %PDIR% ====
echo   src\%UNITY%   il tuo codice
echo   build.bat     compila in build\%PNAME%.exe
echo   .vscode\      build (Ctrl+Shift+B) e debug (F5) in VS Code
echo Chiudi Notepad SENZA salvare: il file ora vive in src\%UNITY%.
start "" explorer "%PDIR%"
where code >nul 2>&1 && start "" code "%PDIR%"
exit /b 0

rem --- cartella progetti: C:\DEV\progetti, altrimenti dentro l'utente ---
:projroot
set "ROOT=C:\DEV\progetti"
if not exist "%ROOT%" mkdir "%ROOT%" >nul 2>&1
(type nul > "%ROOT%\.prova") >nul 2>&1
if exist "%ROOT%\.prova" (
    del "%ROOT%\.prova"
    exit /b 0
)
echo C:\DEV non e' scrivibile, uso la cartella utente.
set "ROOT=%USERPROFILE%\DEV\progetti"
if not exist "%ROOT%" mkdir "%ROOT%" >nul 2>&1
if exist "%ROOT%" exit /b 0
set "ROOT="
exit /b 0

rem --- genera build.bat del progetto ---
:write_build
set "B=%PDIR%\build.bat"
>"%B%"  echo @ECHO OFF
>>"%B%" echo REM Build script for %PNAME%
>>"%B%" echo SetLocal EnableDelayedExpansion
>>"%B%" echo REM i percorsi sono relativi alla cartella di questo script
>>"%B%" echo cd /d "%%~dp0"
>>"%B%" echo.
>>"%B%" echo SET assembly=%PNAME%
>>"%B%" echo SET compilerFlags=-g -gcodeview %STDFLAG% -Wall -Wextra
>>"%B%" echo REM -Werror
>>"%B%" echo SET includeFlags=-Isrc
>>"%B%" echo SET linkerFlags=-static -Wl,--pdb=
>>"%B%" echo SET defines=-D_DEBUG
>>"%B%" echo.
>>"%B%" echo REM --- trova clang (llvm-mingw); se manca lo scarica ---
>>"%B%" echo CALL :find
>>"%B%" echo IF NOT DEFINED DK CALL :install
>>"%B%" echo IF NOT DEFINED DK GOTO :notc
>>"%B%" echo SET "PATH=%%DK%%\bin;%%PATH%%"
>>"%B%" echo.
>>"%B%" echo IF NOT EXIST build MKDIR build
>>"%B%" echo ECHO Building %%assembly%%...
>>"%B%" echo %CC% src\%UNITY% %%compilerFlags%% -o build\%%assembly%%.exe %%defines%% %%includeFlags%% %%linkerFlags%%
>>"%B%" echo IF ERRORLEVEL 1 GOTO :fail
>>"%B%" echo ECHO OK: build\%%assembly%%.exe
>>"%B%" echo EXIT /B 0
>>"%B%" echo.
>>"%B%" echo :fail
>>"%B%" echo ECHO Build fallita.
>>"%B%" echo EXIT /B 1
>>"%B%" echo.
>>"%B%" echo :notc
>>"%B%" echo ECHO [ERRORE] Toolchain non disponibile.
>>"%B%" echo EXIT /B 1
>>"%B%" echo.
>>"%B%" echo :find
>>"%B%" echo SET "DK="
>>"%B%" echo FOR /D %%%%d IN ("%%LOCALAPPDATA%%\llvm-mingw-*") DO IF EXIST "%%%%d\bin\clang.exe" SET "DK=%%%%d"
>>"%B%" echo EXIT /B 0
>>"%B%" echo.
>>"%B%" echo :install
>>"%B%" echo ECHO Toolchain non trovata, la scarico...
>>"%B%" echo curl -fsSL -o "%%TEMP%%\toolchain.bat" %TCURL%
>>"%B%" echo IF ERRORLEVEL 1 EXIT /B 1
>>"%B%" echo CALL "%%TEMP%%\toolchain.bat"
>>"%B%" echo CALL :find
>>"%B%" echo EXIT /B 0
exit /b 0

rem --- genera la configurazione di VS Code ---
:write_vscode
set "DKF=%DK:\=/%"
set "V=%PDIR%\.vscode"

>"%V%\tasks.json"  echo {
>>"%V%\tasks.json" echo   "version": "2.0.0",
>>"%V%\tasks.json" echo   "tasks": [
>>"%V%\tasks.json" echo     {
>>"%V%\tasks.json" echo       "label": "build",
>>"%V%\tasks.json" echo       "type": "process",
>>"%V%\tasks.json" echo       "command": "cmd.exe",
>>"%V%\tasks.json" echo       "args": ["/c", "build.bat"],
>>"%V%\tasks.json" echo       "options": { "cwd": "${workspaceFolder}" },
>>"%V%\tasks.json" echo       "group": { "kind": "build", "isDefault": true },
>>"%V%\tasks.json" echo       "problemMatcher": "$gcc"
>>"%V%\tasks.json" echo     }
>>"%V%\tasks.json" echo   ]
>>"%V%\tasks.json" echo }

>"%V%\launch.json"  echo {
>>"%V%\launch.json" echo   "version": "0.2.0",
>>"%V%\launch.json" echo   "configurations": [
>>"%V%\launch.json" echo     {
>>"%V%\launch.json" echo       "name": "Debug %PNAME%",
>>"%V%\launch.json" echo       "type": "cppvsdbg",
>>"%V%\launch.json" echo       "request": "launch",
>>"%V%\launch.json" echo       "program": "${workspaceFolder}/build/%PNAME%.exe",
>>"%V%\launch.json" echo       "cwd": "${workspaceFolder}",
>>"%V%\launch.json" echo       "preLaunchTask": "build",
>>"%V%\launch.json" echo       "console": "integratedTerminal"
>>"%V%\launch.json" echo     }
>>"%V%\launch.json" echo   ]
>>"%V%\launch.json" echo }

>"%V%\c_cpp_properties.json"  echo {
>>"%V%\c_cpp_properties.json" echo   "configurations": [
>>"%V%\c_cpp_properties.json" echo     {
>>"%V%\c_cpp_properties.json" echo       "name": "llvm-mingw",
>>"%V%\c_cpp_properties.json" echo       "compilerPath": "%DKF%/bin/%CC%.exe",
>>"%V%\c_cpp_properties.json" echo       "intelliSenseMode": "windows-clang-x64",
>>"%V%\c_cpp_properties.json" echo       "includePath": ["${workspaceFolder}/src/**"],
>>"%V%\c_cpp_properties.json" echo       "cStandard": "%CSTD%",
>>"%V%\c_cpp_properties.json" echo       "cppStandard": "c++17"
>>"%V%\c_cpp_properties.json" echo     }
>>"%V%\c_cpp_properties.json" echo   ],
>>"%V%\c_cpp_properties.json" echo   "version": 4
>>"%V%\c_cpp_properties.json" echo }
exit /b 0

rem ------------------------------------------------------------------
:canc
echo.
echo Verranno cancellati DEFINITIVAMENTE (niente Cestino):
echo   - la cartella %WORK% con tutto il contenuto
echo   - la toolchain in %LOCALAPPDATA%\llvm-mingw-*
echo   - il contenuto delle cartelle build dei progetti (il codice resta)
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
for /d %%p in ("C:\DEV\progetti\*" "%USERPROFILE%\DEV\progetti\*") do if exist "%%p\build" (
    rmdir /s /q "%%p\build"
    mkdir "%%p\build"
    echo Svuotata: %%p\build
)
if exist "%TEMP%\llvm-mingw-x" rmdir /s /q "%TEMP%\llvm-mingw-x" >nul 2>&1
del "%TEMP%\llvm-mingw.zip" >nul 2>&1
del "%TEMP%\toolchain.bat" >nul 2>&1
if exist "%WORK%" echo [!] Non sono riuscito a cancellare %WORK% del tutto (file aperto?).
for /d %%d in ("%LOCALAPPDATA%\llvm-mingw-*") do echo [!] Non sono riuscito a cancellare %%d del tutto.
echo Pulizia completata. Cancello anche sketch.bat e chiudo.
rem l'ultima riga cancella lo script stesso mentre termina
(goto) 2>nul & del "%~f0"

rem ------------------------------------------------------------------
:find
set "DK="
for /d %%d in ("%LOCALAPPDATA%\llvm-mingw-*") do if exist "%%d\bin\clang.exe" set "DK=%%d"
exit /b 0

:gettc
echo Toolchain non trovata: scarico toolchain.bat...
curl -fsSL -o "%TEMP%\toolchain.bat" %TCURL% || exit /b 1
call "%TEMP%\toolchain.bat"
exit /b 0
