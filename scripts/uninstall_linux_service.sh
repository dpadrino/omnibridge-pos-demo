#!/usr/bin/env bash
# OmniBridge POS™ — Desinstalador de Servicio Systemd para Linux
# Requiere ejecución con sudo / root

SERVICE_NAME="omnibridge"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

echo "==========================================================="
echo "  OmniBridge POS — Desinstalador de Servicio Linux         "
echo "==========================================================="

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: Este script debe ejecutarse con privilegios de root: sudo bash $0"
    exit 1
fi

echo "[1/3] Deteniendo y deshabilitando servicio $SERVICE_NAME..."
systemctl stop "$SERVICE_NAME" 2>/dev/null || true
systemctl disable "$SERVICE_NAME" 2>/dev/null || true

echo "[2/3] Removiendo archivo de servicio..."
rm -f "$SERVICE_FILE"

echo "[3/3] Recargando demonios de systemd..."
systemctl daemon-reload
systemctl reset-failed 2>/dev/null || true

echo "==========================================================="
echo "  ¡SERVICIO SYSTEMD REMOVIDO CON ÉXITO!                   "
echo "==========================================================="
echo "  Los archivos en /opt/omnibridge han sido preservados."
echo "==========================================================="
