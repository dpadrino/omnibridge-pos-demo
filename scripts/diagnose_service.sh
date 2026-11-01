#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/service_common.sh"
PORT="${1:-8989}"
validate_port
case "$(uname -s)" in
    Linux) PLATFORM=linux ;;
    Darwin) PLATFORM=macos ;;
    *) echo "ERROR: Supported on Linux/macOS only." >&2; exit 1 ;;
esac
failed=0
if service_running; then
    echo "Service manager: RUNNING"
else
    echo "Service manager: NOT RUNNING (or status inaccessible)"
    failed=1
fi
if http_live; then
    echo "HTTP liveness: OK on port $PORT"
else
    echo "HTTP liveness: FAILED on port $PORT"
    failed=1
fi
echo "Read-only diagnostic: no printing, weighing, drawer pulse or queue cleanup."
echo "Liveness does not certify hardware, authentication or the installed build."
exit "$failed"
