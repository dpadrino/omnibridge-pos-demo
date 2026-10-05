@echo off
title OmniBridge POS - Agente de Perifericos
color 0A

echo ========================================================
echo   OmniBridge POS - Agente de Perifericos (Rust)
echo   Bascula + Tickets + Etiquetas + Matriz + Laser
echo ========================================================

rem Cambiar al directorio raiz si se ejecuta desde scripts\
if exist "%~dp0..\pos-peripherals-agent.exe" (
    cd /d "%~dp0.."
) else if exist "%~dp0..\Cargo.toml" (
    cd /d "%~dp0.."
) else (
    cd /d "%~dp0"
)

if not exist "config.toml" (
    echo [AVISO] No se encontro config.toml, copiando desde config.example.toml...
    copy config.example.toml config.toml >nul
)

if exist "pos-peripherals-agent.exe" (
    echo Iniciando binario nativo OmniBridge POS...
    pos-peripherals-agent.exe
) else if exist "pos-peripherals-agent" (
    echo Iniciando binario nativo OmniBridge POS...
    pos-peripherals-agent
) else (
    echo Iniciando via Cargo...
    cargo run --release
)

pause
