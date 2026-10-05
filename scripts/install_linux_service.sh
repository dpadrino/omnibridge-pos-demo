#!/usr/bin/env bash
# OmniBridge POS™ — Instalador de Servicio Systemd para Linux
# Requiere ejecución con sudo / root

set -e

INSTALL_DIR="/opt/omnibridge"
SERVICE_NAME="omnibridge"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

echo "==========================================================="
echo "  OmniBridge POS — Instalador de Servicio Linux (Systemd)  "
echo "==========================================================="

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: Este script debe ejecutarse con privilegios de root: sudo bash $0"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# 1. Crear directorio destino
echo "[1/5] Preparando directorio $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR"

# 2. Localizar y copiar binario
BINARY_SRC=""
if [ -f "$PARENT_DIR/pos-peripherals-agent" ]; then
    BINARY_SRC="$PARENT_DIR/pos-peripherals-agent"
elif [ -f "$PARENT_DIR/target/release/pos-peripherals-agent" ]; then
    BINARY_SRC="$PARENT_DIR/target/release/pos-peripherals-agent"
elif [ -f "./pos-peripherals-agent" ]; then
    BINARY_SRC="./pos-peripherals-agent"
fi

if [ -z "$BINARY_SRC" ] || [ ! -f "$BINARY_SRC" ]; then
    echo "ERROR: No se encontró el binario 'pos-peripherals-agent'. Compile o descomprima el release primero."
    exit 1
fi

echo "[2/5] Instalando binario en $INSTALL_DIR..."
cp "$BINARY_SRC" "$INSTALL_DIR/pos-peripherals-agent"
chmod +x "$INSTALL_DIR/pos-peripherals-agent"

# 3. Copiar configuración base y licencia si existen
if [ ! -f "$INSTALL_DIR/config.toml" ]; then
    if [ -f "$PARENT_DIR/config.toml" ]; then
        cp "$PARENT_DIR/config.toml" "$INSTALL_DIR/config.toml"
    elif [ -f "$PARENT_DIR/config.example.toml" ]; then
        cp "$PARENT_DIR/config.example.toml" "$INSTALL_DIR/config.toml"
    fi
fi

if [ -f "$PARENT_DIR/license.key" ]; then
    cp "$PARENT_DIR/license.key" "$INSTALL_DIR/license.key"
fi

# 4. Asegurar permisos de puerto serial (grupo dialout)
echo "[3/5] Verificando permisos de hardware serial..."
groupadd -f dialout 2>/dev/null || true

# 5. Instalar unidad de servicio systemd
echo "[4/5] Configurando unidad systemd en $SERVICE_FILE..."
if [ -f "$PARENT_DIR/installer/omnibridge.service" ]; then
    cp "$PARENT_DIR/installer/omnibridge.service" "$SERVICE_FILE"
else
    cat << 'EOF' > "$SERVICE_FILE"
[Unit]
Description=OmniBridge POS - Peripherals Gateway Service (Rust)
Documentation=https://github.com/dpadrino/pos-peripherals-agent
After=network.target network-online.target systemd-udev-settle.service
Wants=network-online.target

[Service]
Type=simple
User=root
Group=dialout
WorkingDirectory=/opt/omnibridge
ExecStart=/opt/omnibridge/pos-peripherals-agent
Restart=always
RestartSec=3s
LimitNOFILE=65536
Environment="RUST_LOG=info,pos_peripherals_agent=info"

ProtectSystem=full
ProtectHome=read-only
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF
fi

chmod 644 "$SERVICE_FILE"

# 6. Recargar systemd y activar servicio
echo "[5/5] Activando e iniciando servicio..."
systemctl daemon-reload
systemctl enable --now "$SERVICE_NAME"
sleep 1

if systemctl is-active --quiet "$SERVICE_NAME"; then
    echo "==========================================================="
    echo "  ¡SERVICIO SYSTEMD INSTALADO Y EJECUTÁNDOSE CON ÉXITO!   "
    echo "==========================================================="
    echo "  Servicio        : $SERVICE_NAME.service"
    echo "  Estado          : ACTIVO (running)"
    echo "  Directorio      : $INSTALL_DIR"
    echo "  Dashboard Local : http://127.0.0.1:8989/"
    echo "==========================================================="
else
    echo "ADVERTENCIA: El servicio se instaló pero reporta estado no activo."
    echo "Revise los registros con: journalctl -u $SERVICE_NAME -n 50"
fi
