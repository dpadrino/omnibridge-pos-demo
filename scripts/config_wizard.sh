#!/usr/bin/env bash
# OmniBridge POS - Asistente Gráfico de Configuración (macOS / Linux)
# Abre la interfaz visual de configuración en modo ventana/navegador limpio.

URL="http://127.0.0.1:8989/#config-wizard"

echo "Abriendo Asistente de Configuración de OmniBridge POS..."

if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS: Abrir en el navegador predeterminado
    open "$URL"
elif command -v google-chrome >/dev/null 2>&1; then
    # Linux: Chrome en modo aplicación (ventana independiente)
    google-chrome --app="$URL" &
elif command -v chromium-browser >/dev/null 2>&1; then
    chromium-browser --app="$URL" &
elif command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$URL"
else
    echo "Abra en su navegador la siguiente dirección para configurar:"
    echo "$URL"
fi
