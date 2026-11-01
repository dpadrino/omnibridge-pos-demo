#!/usr/bin/env bash
set -euo pipefail
[ "$(uname -s)" = "Linux" ] || { echo "ERROR: Linux installer only." >&2; exit 1; }
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PLATFORM=linux
APP_DIR=/opt/omnibridge
BIN_TARGET="$APP_DIR/pos-peripherals-agent"
SERVICE_FILE=/etc/systemd/system/omnibridge.service
PORT="${1:-8989}"
# shellcheck source=service_common.sh
source "$SCRIPT_DIR/service_common.sh"
install_service
