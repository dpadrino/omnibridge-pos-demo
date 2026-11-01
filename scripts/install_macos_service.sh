#!/usr/bin/env bash
set -euo pipefail
[ "$(uname -s)" = "Darwin" ] || { echo "ERROR: macOS installer only." >&2; exit 1; }
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PLATFORM=macos
APP_DIR="/Library/Application Support/OmniBridgePOS"
LOG_DIR=/Library/Logs/OmniBridgePOS
BIN_TARGET=/usr/local/bin/pos-peripherals-agent
SERVICE_FILE=/Library/LaunchDaemons/com.omnibridge.pos.plist
PORT="${1:-8989}"
# shellcheck source=service_common.sh
source "$SCRIPT_DIR/service_common.sh"
install_service
