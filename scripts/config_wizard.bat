@echo off
rem OmniBridge POS - Asistente Grafico de Configuracion (Windows)
rem Abre la interfaz de configuracion en una ventana de aplicacion limpia sin marcos.

set URL=http://127.0.0.1:8989/#config-wizard

echo Abriendo Asistente de Configuracion de OmniBridge POS...

rem Intentar abrir en Microsoft Edge en modo aplicacion (ventana nativa)
where msedge >nul 2>&1
if %ERRORLEVEL% equ 0 (
    start msedge --app="%URL%"
    exit /b 0
)

rem Intentar abrir en Google Chrome en modo aplicacion
where chrome >nul 2>&1
if %ERRORLEVEL% equ 0 (
    start chrome --app="%URL%"
    exit /b 0
)

rem Fallback: abrir en el navegador predeterminado del sistema
start "" "%URL%"
exit /b 0
