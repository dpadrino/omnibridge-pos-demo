@echo off
setlocal
title OmniBridge POS - Salud y Reparacion de Impresora POS-80

:: 1. Comprobar permisos de Administrador y auto-elevar si es necesario
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [OmniBridge POS] Solicitando permisos de Administrador para gestionar el Spooler e Impresoras...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -ArgumentList '%*' -Verb RunAs"
    exit /b
)

:: 2. Ejecutar script de salud de PowerShell
pushd "%~dp0"
if "%~1"=="" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0printer_health.ps1" -Interactive
) else (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0printer_health.ps1" %*
)
set EXIT_CODE=%errorlevel%
popd

:: 3. Mensaje de cierre
if %EXIT_CODE% neq 0 (
    if %EXIT_CODE% neq 2 (
        echo.
        echo [AVISO] El script finalizo con codigo: %EXIT_CODE%
    )
)

echo.
echo Presione cualquier tecla para cerrar esta ventana...
pause >nul
