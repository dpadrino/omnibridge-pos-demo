#!/usr/bin/env bash
# OmniBridge POS™ — Instalador de Servicio Launchd para macOS
# Requiere ejecución con sudo

set -e

PLIST_NAME="com.omnibridge.pos"
PLIST_FILE="/Library/LaunchDaemons/${PLIST_NAME}.plist"
APP_DIR="/Library/Application Support/OmniBridgePOS"
LOG_DIR="/Library/Logs/OmniBridgePOS"
BIN_TARGET="/usr/local/bin/pos-peripherals-agent"

echo "==========================================================="
echo "  OmniBridge POS — Instalador de Servicio macOS (Launchd)  "
echo "==========================================================="

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: Este script debe ejecutarse con sudo: sudo bash $0"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# 1. Crear directorios requeridos
echo "[1/6] Creando directorios en el sistema..."
mkdir -p "$APP_DIR"
mkdir -p "$LOG_DIR"
mkdir -p "/usr/local/bin"

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

echo "[2/6] Copiando binario a /usr/local/bin..."
cp "$BINARY_SRC" "$BIN_TARGET"
chmod +x "$BIN_TARGET"

# 3. Remover atributo de cuarentena de Gatekeeper si fue descargado por navegador
echo "[3/6] Desactivando atributos de cuarentena Gatekeeper..."
xattr -cr "$BIN_TARGET" 2>/dev/null || true

# 4. Copiar configuración base y licencia
echo "[4/6] Configurando entorno de ejecución en $APP_DIR..."
if [ ! -f "$APP_DIR/config.toml" ]; then
    if [ -f "$PARENT_DIR/config.toml" ]; then
        cp "$PARENT_DIR/config.toml" "$APP_DIR/config.toml"
    elif [ -f "$PARENT_DIR/config.example.toml" ]; then
        cp "$PARENT_DIR/config.example.toml" "$APP_DIR/config.toml"
    fi
fi

if [ -f "$PARENT_DIR/license.key" ]; then
    cp "$PARENT_DIR/license.key" "$APP_DIR/license.key"
fi

# 5. Instalar archivo launchd plist
echo "[5/6] Instalando definición del demonio launchd en $PLIST_FILE..."
if [ -f "$PARENT_DIR/installer/com.omnibridge.pos.plist" ]; then
    cp "$PARENT_DIR/installer/com.omnibridge.pos.plist" "$PLIST_FILE"
else
    cat << 'EOF' > "$PLIST_FILE"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.omnibridge.pos</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/pos-peripherals-agent</string>
    </array>
    <key>WorkingDirectory</key>
    <string>/Library/Application Support/OmniBridgePOS</string>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/Library/Logs/OmniBridgePOS/agent.log</string>
    <key>StandardErrorPath</key>
    <string>/Library/Logs/OmniBridgePOS/agent_error.log</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>RUST_LOG</key>
        <string>info,pos_peripherals_agent=info</string>
    </dict>
</dict>
</plist>
EOF
fi

chown root:wheel "$PLIST_FILE"
chmod 644 "$PLIST_FILE"

# 6. Cargar servicio
echo "[6/6] Iniciando demonio en launchd..."
launchctl unload -w "$PLIST_FILE" 2>/dev/null || true
launchctl load -w "$PLIST_FILE"
sleep 1

echo "==========================================================="
echo "  ¡SERVICIO LAUNCHD INSTALADO Y EJECUTÁNDOSE CON ÉXITO!   "
echo "==========================================================="
echo "  Etiqueta        : $PLIST_NAME"
echo "  Binario         : $BIN_TARGET"
echo "  Directorio      : $APP_DIR"
echo "  Logs            : $LOG_DIR/agent.log"
echo "  Dashboard Local : http://127.0.0.1:8989/"
echo "==========================================================="
