@echo off
REM Lumen - friendly programming language
REM Usage: lumen script.ln
REM        lumen             (starts REPL)

setlocal

:: Find the directory where this script lives
set "LUMEN_DIR=%~dp0"

:: Run the Lumen interpreter
if "%~1"=="" (
    pwsh.exe -NoProfile -ExecutionPolicy Bypass -Command "& '%LUMEN_DIR%lumen.ps1'"
) else (
    pwsh.exe -NoProfile -ExecutionPolicy Bypass -Command "& '%LUMEN_DIR%lumen.ps1' '%~1'"
)

endlocal
