#!/usr/bin/env bash
# OmniBridge POS™ — Desinstalador de Servicio Launchd para macOS
# Requiere ejecución con sudo

PLIST_NAME="com.omnibridge.pos"
PLIST_FILE="/Library/LaunchDaemons/${PLIST_NAME}.plist"

echo "==========================================================="
echo "  OmniBridge POS — Desinstalador de Servicio macOS         "
echo "==========================================================="

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: Este script debe ejecutarse con sudo: sudo bash $0"
    exit 1
fi

echo "[1/2] Descargando y deteniendo demonio launchd..."
launchctl unload -w "$PLIST_FILE" 2>/dev/null || true

echo "[2/2] Removiendo archivo de definición plist..."
rm -f "$PLIST_FILE"

echo "==========================================================="
echo "  ¡SERVICIO LAUNCHD REMOVIDO CON ÉXITO!                   "
echo "==========================================================="
echo "  Los archivos en /Library/Application Support/OmniBridgePOS"
echo "  han sido preservados."
echo "==========================================================="
