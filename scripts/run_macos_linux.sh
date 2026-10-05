#!/usr/bin/env bash
set -e

# Detectar directorio raíz del paquete (si se ejecuta desde scripts/ o desde la raíz)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/pos-peripherals-agent" ]; then
    ROOT_DIR="$SCRIPT_DIR"
elif [ -f "$SCRIPT_DIR/../pos-peripherals-agent" ]; then
    ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
else
    ROOT_DIR="$PWD"
fi

cd "$ROOT_DIR"

echo "========================================================"
echo "  OmniBridge POS - Agente de Periféricos (Rust)"
echo "  Báscula + Tickets + Etiquetas + Matriz + Láser"
echo "========================================================"

if [ ! -f "config.toml" ]; then
    echo "[AVISO] No se encontró config.toml, copiando desde config.example.toml..."
    cp config.example.toml config.toml
fi

if [ -f "./pos-peripherals-agent" ]; then
    chmod +x ./pos-peripherals-agent 2>/dev/null || true
    if [[ "$OSTYPE" == "darwin"* ]]; then
        xattr -d com.apple.quarantine ./pos-peripherals-agent 2>/dev/null || true
        xattr -cr . 2>/dev/null || true
    fi
    echo "Iniciando binario nativo OmniBridge POS..."
    exec ./pos-peripherals-agent
elif command -v cargo >/dev/null 2>&1; then
    echo "Iniciando vía Cargo..."
    exec cargo run --release
else
    echo "Error: No se encontró el binario 'pos-peripherals-agent' ni Cargo instalado en este sistema."
    exit 1
fi
