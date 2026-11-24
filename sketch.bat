@echo off
rem ==================================================================
rem  sketch.bat - foglio di allenamento quotidiano (clang / clang++)
rem  Uso:  sketch          -> C99  (gabcode.c)
rem        sketch c89      -> C89  (gabcode.c)
rem        sketch cpp      -> C++  (gabcode.cpp)
rem        sketch gfx      -> C99 + raylib (finestra grafica)
rem        sketch canc     -> cancella tutto
rem        sketch help     -> elenco comandi
rem
rem  Script di supporto nello stesso repo:
rem    toolchain.bat (clang), debugger.bat (RAD Debugger), raylib.bat
rem ==================================================================
setlocal
set "BASEURL=https://gablab-studio.github.io"
set "TCURL=%BASEURL%/toolchain.bat"
set "DBGURL=%BASEURL%/debugger.bat"
set "RLURL=%BASEURL%/raylib.bat"
set "WORK=%USERPROFILE%\gabcode"
set "STORICO=%USERPROFILE%\gabcode\storico"
set "KATA=%USERPROFILE%\gabcode\kata.csv"
set "INLOOP="
set "STRICT="

set "ARGMODE=%~1"
if "%ARGMODE%"=="" set "ARGMODE=c99"
if /i "%ARGMODE%"=="canc" goto canc
if /i "%ARGMODE%"=="help" (
    call :help
    exit /b 0
)
call :setmode %ARGMODE%
if errorlevel 1 exit /b 1

if not exist "%WORK%" mkdir "%WORK%"
cd /d "%WORK%"

rem --- i vecchi old_gabcode.* delle versioni precedenti finiscono nello storico ---
for %%f in (old_gabcode.c old_gabcode.cpp) do if exist "%%f" call :archivia "%%f"

rem --- foglio bianco subito: scrivi mentre si scarica il resto ---
call :newsheet

rem --- compilatore: se manca, lo procura toolchain.bat ---
call :find
if not defined DK call :gettc
if not defined DK (
    echo [ERRORE] Compilatore non disponibile.
    pause
    exit /b 1
)
set "PATH=%DK%\bin;%PATH%"

rem --- raylib solo in modalita' gfx ---
if defined GFX (
    call :needrl
    if errorlevel 1 (
        pause
        exit /b 1
    )
)
echo Compilatore pronto: %DK%
echo Cartella di lavoro: %WORK%
echo Scrivi help per l'elenco dei comandi.
set "INLOOP=1"

rem ==================================================================
:build
title sketch [%MODE%]
echo.
if defined STRICT (set "STAG= strict") else (set "STAG=")
echo ---- [%MODE%%STAG%] Salva con Ctrl+S, poi Invio = compila ed esegui   (help = comandi) ----
set "SCELTA="
set "CMD1="
set "ARG1="
set /p "SCELTA=> "
for /f "tokens=1,2" %%a in ("%SCELTA%") do (
    set "CMD1=%%a"
    set "ARG1=%%b"
)
if "%CMD1%"=="" goto run
if /i "%CMD1%"=="help" (
    call :help
    goto build
)
if /i "%CMD1%"=="apri" goto apri
if /i "%CMD1%"=="debug" goto debug
if /i "%CMD1%"=="mode" goto cambiamodo
if /i "%CMD1%"=="strict" goto strict
if /i "%CMD1%"=="kata" goto showkata
if /i "%CMD1%"=="storico" goto storico
if /i "%CMD1%"=="persist" goto persist
if /i "%CMD1%"=="canc" goto canc
if /i "%CMD1%"=="esci" exit /b 0
echo Comando sconosciuto: %CMD1%   (scrivi help)
goto build

rem ------------------------------------------------------------------
:run
set "OPT=-O2"
call :compile
if errorlevel 1 goto build
echo ==== Avvio gabcode.exe in una nuova finestra (Ctrl+C la chiude, lo sketch resta vivo) ====
start "gabcode" /wait cmd /v:on /c "gabcode.exe & echo. & echo ==== gabcode.exe terminato: codice !errorlevel! ==== & pause"
goto build

rem ------------------------------------------------------------------
:debug
set "OPT=-g -gcodeview -O0 -Wl,--pdb="
call :compile
if errorlevel 1 goto build
call :finddbg
if not defined RDBG call :getdbg
if not defined RDBG (
    echo [ERRORE] Debugger non disponibile.
    goto build
)
echo ==== Apro gabcode.exe in RAD Debugger: chiudilo per tornare qui ====
start "" /wait "%RDBG%" gabcode.exe
goto build

rem ------------------------------------------------------------------
:apri
if not exist "%SRC%" type nul > "%SRC%"
start "" notepad "%SRC%"
goto build

rem ------------------------------------------------------------------
:strict
if defined STRICT (
    set "STRICT="
    echo strict OFF: gli avvisi sono di nuovo solo avvisi.
) else (
    set "STRICT=1"
    echo strict ON: ogni avviso blocca la compilazione ^(-Werror^).
)
goto build

rem ------------------------------------------------------------------
:storico
if not exist "%STORICO%" (
    echo Lo storico e' ancora vuoto.
    goto build
)
start "" explorer "%STORICO%"
goto build

rem ------------------------------------------------------------------
:cambiamodo
if "%ARG1%"=="" (
    echo Uso: mode c99 ^| c89 ^| cpp ^| gfx      ^(ora: %MODE%^)
    goto build
)
set "OLDMODE=%MODE%"
set "OLDSRC=%SRC%"
call :setmode %ARG1%
if errorlevel 1 goto build
if defined GFX (
    call :needrl
    if errorlevel 1 (
        echo Resto in modalita' %OLDMODE%.
        call :setmode %OLDMODE%
        goto build
    )
)
if /i not "%OLDSRC%"=="%SRC%" (
    if exist "%SRC%" call :archivia "%SRC%"
    if exist "%OLDSRC%" move /y "%OLDSRC%" "%SRC%" >nul
    if not exist "%SRC%" type nul > "%SRC%"
    start "" notepad "%SRC%"
    echo Il tuo codice ora e' in %SRC% e l'ho aperto in un nuovo Notepad.
    echo Chiudi il Notepad di %OLDSRC% SENZA salvare.
)
echo Modalita': %MODE%
goto build

rem ------------------------------------------------------------------
:showkata
if not exist "%KATA%" (
    echo Nessun risultato ancora: completa uno sketch con una compilazione riuscita.
    goto build
)
echo.
echo   data                 modo   tempo  falliti
for /f "usebackq skip=1 tokens=1-4 delims=;" %%a in ("%KATA%") do call :katarow %%a %%b %%c %%d
echo.
for %%m in (c99 c89 cpp gfx) do call :katabest %%m
goto build

:katarow
call :fmt KT %3
echo   %1  %2    %KT%   %4
exit /b 0

:katabest
call :best %1
if defined BEST (
    call :fmt KT %BEST%
    call echo   record %1: %%KT%%
)
exit /b 0

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
move /y "%WORK%\%SRC%" "%PDIR%\src\%MAINF%" >nul
call :write_unity
if exist "%WORK%\gabcode.exe" del "%WORK%\gabcode.exe"
if exist "%WORK%\gabcode.pdb" del "%WORK%\gabcode.pdb"
call :write_build
call :write_vscode
>"%PDIR%\.gitignore" echo build/
echo.
echo ==== Progetto creato: %PDIR% ====
echo   src\%MAINF%      il tuo codice
echo   src\%UNITY%     unity build: include main e gli altri file
echo   build.bat     compila in build\%PNAME%.exe   (build debug = compila e apri il debugger)
echo   .vscode\      build (Ctrl+Shift+B) e debug (F5) in VS Code
start "" explorer "%PDIR%"
where code >nul 2>&1 && start "" code "%PDIR%"
echo.
echo Chiudi il vecchio Notepad SENZA salvare: il codice ora vive in src\%MAINF%.
echo Ti ho aperto un foglio nuovo, si riparte.
call :newsheet
goto build

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

rem --- genera il file della unity build ---
:write_unity
set "U=%PDIR%\src\%UNITY%"
>"%U%" echo #include "%MAINF%"
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
>>"%B%" echo REM --- trova clang (llvm-mingw); se manca lo scarica ---
>>"%B%" echo CALL :find
>>"%B%" echo IF NOT DEFINED DK CALL :install
>>"%B%" echo IF NOT DEFINED DK GOTO :notc
>>"%B%" echo SET "PATH=%%DK%%\bin;%%PATH%%"
if defined GFX (
>>"%B%" echo REM --- trova raylib; se manca la scarica ---
>>"%B%" echo CALL :findrl
>>"%B%" echo IF NOT DEFINED RL CALL :installrl
>>"%B%" echo IF NOT DEFINED RL GOTO :norl
)
>>"%B%" echo.
>>"%B%" echo SET assembly=%PNAME%
>>"%B%" echo SET compilerFlags=-g -gcodeview %STDFLAG% -Wall -Wextra
>>"%B%" echo REM -Werror
if defined GFX (
>>"%B%" echo SET includeFlags=-Isrc -isystem "%%RL%%\include"
>>"%B%" echo SET linkerFlags=-static -Wl,--pdb= -L"%%RL%%\lib" -lraylib -lopengl32 -lgdi32 -lwinmm
) else (
>>"%B%" echo SET includeFlags=-Isrc
>>"%B%" echo SET linkerFlags=-static -Wl,--pdb=
)
>>"%B%" echo SET defines=-D_DEBUG
>>"%B%" echo.
>>"%B%" echo IF NOT EXIST build MKDIR build
>>"%B%" echo ECHO Building %%assembly%%...
>>"%B%" echo %CC% src\%UNITY% %%compilerFlags%% -o build\%%assembly%%.exe %%defines%% %%includeFlags%% %%linkerFlags%%
>>"%B%" echo IF ERRORLEVEL 1 GOTO :fail
>>"%B%" echo ECHO OK: build\%%assembly%%.exe
>>"%B%" echo IF /I "%%~1"=="debug" GOTO :debug
>>"%B%" echo EXIT /B 0
>>"%B%" echo.
>>"%B%" echo :debug
>>"%B%" echo CALL :findd
>>"%B%" echo IF NOT DEFINED RDBG CALL :installd
>>"%B%" echo IF NOT DEFINED RDBG GOTO :nodbg
>>"%B%" echo ECHO Apro build\%%assembly%%.exe in RAD Debugger...
>>"%B%" echo START "" "%%RDBG%%" build\%%assembly%%.exe
>>"%B%" echo EXIT /B 0
>>"%B%" echo.
>>"%B%" echo :nodbg
>>"%B%" echo ECHO [ERRORE] Debugger non disponibile.
>>"%B%" echo EXIT /B 1
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
>>"%B%" echo.
>>"%B%" echo :findd
>>"%B%" echo SET "RDBG="
>>"%B%" echo IF EXIST "%%LOCALAPPDATA%%\raddbg" FOR /R "%%LOCALAPPDATA%%\raddbg" %%%%f IN (raddbg.exe) DO IF EXIST "%%%%f" SET "RDBG=%%%%f"
>>"%B%" echo EXIT /B 0
>>"%B%" echo.
>>"%B%" echo :installd
>>"%B%" echo ECHO Debugger non trovato, lo scarico...
>>"%B%" echo curl -fsSL -o "%%TEMP%%\debugger.bat" %DBGURL%
>>"%B%" echo IF ERRORLEVEL 1 EXIT /B 1
>>"%B%" echo CALL "%%TEMP%%\debugger.bat"
>>"%B%" echo CALL :findd
>>"%B%" echo EXIT /B 0
if defined GFX (
>>"%B%" echo.
>>"%B%" echo :norl
>>"%B%" echo ECHO [ERRORE] raylib non disponibile.
>>"%B%" echo EXIT /B 1
>>"%B%" echo.
>>"%B%" echo :findrl
>>"%B%" echo SET "RL="
>>"%B%" echo FOR /D %%%%d IN ^("%%LOCALAPPDATA%%\raylib-*"^) DO IF EXIST "%%%%d\include\raylib.h" SET "RL=%%%%d"
>>"%B%" echo EXIT /B 0
>>"%B%" echo.
>>"%B%" echo :installrl
>>"%B%" echo ECHO raylib non trovata, la scarico...
>>"%B%" echo curl -fsSL -o "%%TEMP%%\raylib.bat" %RLURL%
>>"%B%" echo IF ERRORLEVEL 1 EXIT /B 1
>>"%B%" echo CALL "%%TEMP%%\raylib.bat"
>>"%B%" echo CALL :findrl
>>"%B%" echo EXIT /B 0
)
exit /b 0

rem --- genera la configurazione di VS Code ---
:write_vscode
set "DKF=%DK:\=/%"
set "INCX="
if defined GFX set "INCX=, "%RL:\=/%/include""
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
>>"%V%\c_cpp_properties.json" echo       "includePath": ["${workspaceFolder}/src/**"%INCX%],
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
echo   - la cartella %WORK% (sketch, storico, statistiche kata)
echo   - la toolchain in %LOCALAPPDATA%\llvm-mingw-*
echo   - il debugger in %LOCALAPPDATA%\raddbg
echo   - raylib in %LOCALAPPDATA%\raylib-*
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
for /d %%d in ("%LOCALAPPDATA%\raylib-*") do rmdir /s /q "%%d"
if exist "%LOCALAPPDATA%\raddbg" rmdir /s /q "%LOCALAPPDATA%\raddbg"
if exist "%APPDATA%\raddbg" rmdir /s /q "%APPDATA%\raddbg"
for /d %%p in ("C:\DEV\progetti\*" "%USERPROFILE%\DEV\progetti\*") do if exist "%%p\build" (
    rmdir /s /q "%%p\build"
    mkdir "%%p\build"
    echo Svuotata: %%p\build
)
if exist "%TEMP%\llvm-mingw-x" rmdir /s /q "%TEMP%\llvm-mingw-x" >nul 2>&1
for %%t in (llvm-mingw.zip raddbg.zip raylib.zip toolchain.bat debugger.bat raylib.bat) do del "%TEMP%\%%t" >nul 2>&1
if exist "%WORK%" echo [!] Non sono riuscito a cancellare %WORK% del tutto (file aperto?).
for /d %%d in ("%LOCALAPPDATA%\llvm-mingw-*") do echo [!] Non sono riuscito a cancellare %%d del tutto.
for /d %%d in ("%LOCALAPPDATA%\raylib-*") do echo [!] Non sono riuscito a cancellare %%d del tutto.
if exist "%LOCALAPPDATA%\raddbg" echo [!] Non sono riuscito a cancellare %LOCALAPPDATA%\raddbg (debugger aperto?).
echo Pulizia completata. Cancello anche sketch.bat e chiudo.
rem l'ultima riga cancella lo script stesso mentre termina
(goto) 2>nul & del "%~f0"

rem ==================================================================
rem  Sottoprogrammi
rem ==================================================================

:help
echo.
echo  Avvio:   sketch [c99 ^| c89 ^| cpp ^| gfx]     sketch canc     sketch help
echo.
echo  Al prompt ^>:
echo    [Invio]       compila ed esegui (in una finestra separata)
echo    debug         compila in debug e apri RAD Debugger
echo    apri          riapri Notepad sul file dello sketch
echo    mode X        cambia modalita': c99, c89, cpp, gfx
echo    strict        attiva/disattiva -Werror (avvisi = errori)
echo    kata          tempi e record delle tue sessioni
echo    storico       apri la cartella con gli sketch dei giorni passati
echo    persist       trasforma lo sketch in un progetto (poi foglio nuovo)
echo    canc          cancella tutto: sketch, toolchain, debugger, raylib, build
echo    esci          chiudi lo script
exit /b 0

rem --- imposta la modalita'; errorlevel 1 se sconosciuta (niente cambia) ---
:setmode
if /i "%~1"=="c99" goto sm_c99
if /i "%~1"=="c89" goto sm_c89
if /i "%~1"=="cpp" goto sm_cpp
if /i "%~1"=="gfx" goto sm_gfx
echo [ERRORE] Modalita' sconosciuta: "%~1"
echo Modalita' valide: c99 (predefinita), c89, cpp, gfx
exit /b 1
:sm_c99
set "MODE=c99"
set "SRC=gabcode.c"
set "CC=clang"
set "STDFLAG=-std=c99"
set "UNITY=unity.c"
set "MAINF=main.c"
set "CSTD=c99"
set "GFX="
exit /b 0
:sm_c89
set "MODE=c89"
set "SRC=gabcode.c"
set "CC=clang"
set "STDFLAG=-std=c89 -pedantic"
set "UNITY=unity.c"
set "MAINF=main.c"
set "CSTD=c89"
set "GFX="
exit /b 0
:sm_cpp
set "MODE=cpp"
set "SRC=gabcode.cpp"
set "CC=clang++"
set "STDFLAG=-std=c++17"
set "UNITY=unity.cpp"
set "MAINF=main.cpp"
set "CSTD=c99"
set "GFX="
exit /b 0
:sm_gfx
rem raylib.h richiede almeno C99
set "MODE=gfx"
set "SRC=gabcode.c"
set "CC=clang"
set "STDFLAG=-std=c99"
set "UNITY=unity.c"
set "MAINF=main.c"
set "CSTD=c99"
set "GFX=1"
exit /b 0

rem --- compila lo sketch; OPT = flag extra; errorlevel 1 se fallisce ---
:compile
set "SFLAG="
if defined STRICT set "SFLAG=-Werror"
set "GFXF="
if defined GFX set "GFXF=-isystem "%RL%\include" -L"%RL%\lib" -lraylib -lopengl32 -lgdi32 -lwinmm"
%CC% %STDFLAG% -Wall -Wextra %SFLAG% %OPT% -static "%SRC%" -o gabcode.exe %GFXF%
if errorlevel 1 (
    set /a FAILS+=1
    echo ==== Errori di compilazione: correggi in Notepad e riprova ====
    exit /b 1
)
if not defined KATADONE call :katarecord
exit /b 0

rem --- foglio bianco: archivia quello attuale, apre Notepad, parte il cronometro ---
:newsheet
if exist "%SRC%" call :archivia "%SRC%"
type nul > "%SRC%"
start "" notepad "%SRC%"
call :now T0
set "FAILS=0"
set "KATADONE="
exit /b 0

rem --- sposta un file nello storico con data e ora (i file vuoti si cancellano) ---
:archivia
set "SZ=0"
for %%A in ("%~1") do set "SZ=%%~zA"
if "%SZ%"=="0" (
    del "%~1" >nul 2>&1
    exit /b 0
)
call :stamp
if not exist "%STORICO%" mkdir "%STORICO%"
move /y "%~1" "%STORICO%\%STAMP%_%~nx1" >nul
exit /b 0

rem --- kata: registra il tempo della prima compilazione riuscita ---
:katarecord
set "KATADONE=1"
call :now T1
set /a ELAPSED=T1-T0
call :best %MODE%
set "PREV=%BEST%"
call :stamp
if not exist "%KATA%" >"%KATA%" echo data;modo;secondi;falliti
>>"%KATA%" echo %STAMP%;%MODE%;%ELAPSED%;%FAILS%
call :fmt KT %ELAPSED%
echo ==== Kata: prima compilazione riuscita in %KT% con %FAILS% tentativi falliti ====
if not defined PREV (
    echo ==== Primo risultato registrato per %MODE% ====
    exit /b 0
)
if %ELAPSED% LSS %PREV% (
    echo ==== NUOVO RECORD per %MODE%! ====
    exit /b 0
)
call :fmt KT %PREV%
echo ==== Record %MODE%: %KT% ====
exit /b 0

rem --- BEST = tempo migliore (secondi) per la modalita' %1, vuoto se nessuno ---
:best
set "BEST="
if not exist "%KATA%" exit /b 0
for /f "usebackq skip=1 tokens=2,3 delims=;" %%a in ("%KATA%") do if /i "%%a"=="%~1" call :minsec %%b
exit /b 0
:minsec
if not defined BEST (
    set "BEST=%1"
    exit /b 0
)
if %1 LSS %BEST% set "BEST=%1"
exit /b 0

rem --- %1 = secondi %2 formattati come m:ss ---
:fmt
set /a _m=%2/60, _s=%2%%60
if %_s% LSS 10 set "_s=0%_s%"
set "%1=%_m%:%_s%"
exit /b 0

rem --- %1 = secondi dal 1970 (orologio indipendente dalla lingua di Windows) ---
:now
set "%~1=0"
for /f %%s in ('powershell -NoProfile -Command "[DateTimeOffset]::Now.ToUnixTimeSeconds()"') do set "%~1=%%s"
exit /b 0

rem --- STAMP = data e ora tipo 2026-11-24_14-22-05 ---
:stamp
set "STAMP=senza-data"
for /f %%t in ('powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd_HH-mm-ss"') do set "STAMP=%%t"
exit /b 0

rem --- toolchain ---
:find
set "DK="
for /d %%d in ("%LOCALAPPDATA%\llvm-mingw-*") do if exist "%%d\bin\clang.exe" set "DK=%%d"
exit /b 0

:gettc
echo Toolchain non trovata: scarico toolchain.bat...
curl -fsSL -o "%TEMP%\toolchain.bat" %TCURL% || exit /b 1
call "%TEMP%\toolchain.bat"
exit /b 0

rem --- debugger ---
:finddbg
set "RDBG="
if exist "%LOCALAPPDATA%\raddbg" for /r "%LOCALAPPDATA%\raddbg" %%f in (raddbg.exe) do if exist "%%f" set "RDBG=%%f"
exit /b 0

:getdbg
echo Debugger non trovato: scarico debugger.bat...
curl -fsSL -o "%TEMP%\debugger.bat" %DBGURL% || exit /b 1
call "%TEMP%\debugger.bat"
exit /b 0

rem --- raylib ---
:needrl
call :findrl
if not defined RL call :getrl
if not defined RL (
    echo [ERRORE] raylib non disponibile.
    exit /b 1
)
exit /b 0

:findrl
set "RL="
for /d %%d in ("%LOCALAPPDATA%\raylib-*") do if exist "%%d\include\raylib.h" set "RL=%%d"
exit /b 0

:getrl
echo raylib non trovata: scarico raylib.bat...
curl -fsSL -o "%TEMP%\raylib.bat" %RLURL% || exit /b 1
call "%TEMP%\raylib.bat"
call :findrl
exit /b 0
