#!/usr/bin/env bash
# Shared by installers and diagnostics; sourcing this file changes no service.

service_running() {
    if [ "$PLATFORM" = "linux" ]; then
        systemctl is-active --quiet omnibridge
    else
        launchctl print system/com.omnibridge.pos 2>/dev/null | grep -Eq 'pid = [0-9]+'
    fi
}

service_exists() {
    if [ "$PLATFORM" = "linux" ]; then
        systemctl cat omnibridge >/dev/null 2>&1
    else
        launchctl print system/com.omnibridge.pos >/dev/null 2>&1
    fi
}

service_stop() {
    if [ "$PLATFORM" = "linux" ]; then
        systemctl stop omnibridge
    else
        launchctl bootout system/com.omnibridge.pos
    fi
}

service_start() {
    if [ "$PLATFORM" = "linux" ]; then
        systemctl daemon-reload && systemctl enable omnibridge && systemctl start omnibridge
    else
        launchctl enable system/com.omnibridge.pos && launchctl bootstrap system "$SERVICE_FILE"
    fi
}

http_live() {
    local response
    # Expected probe failures must not inherit the installer's rollback trap.
    response=$(trap - ERR; curl --noproxy '*' --fail --silent --show-error --connect-timeout 1 --max-time 2 \
        "http://127.0.0.1:$PORT/api/v1/health/live") || return 1
    [[ "$response" =~ ^[[:space:]]*\{[[:space:]]*\"status\"[[:space:]]*:[[:space:]]*\"ok\"[[:space:]]*\}[[:space:]]*$ ]]
}

wait_for_service() {
    local attempt
    for attempt in {1..10}; do
        if service_running && http_live; then
            return 0
        fi
        sleep 1
    done
    echo "ERROR: Service or HTTP liveness unavailable on port $PORT." >&2
    return 1
}

validate_port() {
    [[ "$PORT" =~ ^[0-9]{1,5}$ ]] && [ "$PORT" -ge 1 ] && [ "$PORT" -le 65535 ] || {
        echo "ERROR: Port must be an integer from 1 to 65535." >&2
        return 1
    }
}

install_service() (
    set -Eeuo pipefail
    umask 077
    validate_port
    [ "$(id -u)" -eq 0 ] || { echo "ERROR: Run installer with sudo." >&2; exit 1; }
    staged=""
    stopped=0
    existed=0
    manager=systemctl
    unit=omnibridge.service
    if [ "$PLATFORM" = "macos" ]; then
        manager=launchctl
        unit=com.omnibridge.pos.plist
    fi
    command -v "$manager" >/dev/null
    command -v curl >/dev/null
    source_binary="$PACKAGE_DIR/pos-peripherals-agent"
    if [ ! -f "$source_binary" ]; then
        source_binary="$PACKAGE_DIR/target/release/pos-peripherals-agent"
    fi
    [ -f "$source_binary" ] || { echo "ERROR: Package binary missing." >&2; exit 1; }
    [ -f "$PACKAGE_DIR/installer/$unit" ] || { echo "ERROR: Service definition missing." >&2; exit 1; }
    source_config="$PACKAGE_DIR/config.toml"
    [ -f "$source_config" ] || source_config="$PACKAGE_DIR/config.example.toml"
    if [ ! -f "$APP_DIR/config.toml" ] && [ ! -f "$source_config" ]; then
        echo "ERROR: Initial configuration missing." >&2
        exit 1
    fi
    for path in "$APP_DIR" "$BIN_TARGET" "$SERVICE_FILE" "$APP_DIR/config.toml" "$APP_DIR/license.key"; do
        [ ! -L "$path" ] || { echo "ERROR: Symbolic link at installation destination: $path" >&2; exit 1; }
    done
    if [ "$PLATFORM" = "macos" ]; then
        plutil -lint "$PACKAGE_DIR/installer/$unit"
    else
        getent group dialout >/dev/null || { echo "ERROR: Create the dialout group before installing." >&2; exit 1; }
    fi
    mkdir -p "$APP_DIR" "$(dirname "$BIN_TARGET")" "$(dirname "$SERVICE_FILE")"
    if ! mkdir "$APP_DIR/.install-lock"; then
        echo "ERROR: Another install is running or a stale .install-lock needs operator review." >&2
        exit 1
    fi
    cleanup() {
        [ -z "$staged" ] || [ ! -f "$staged" ] || rm -f "$staged"
        rmdir "$APP_DIR/.install-lock"
    }
    trap cleanup EXIT
    backup=$(mktemp -d "$APP_DIR/install-backup.XXXXXX")
    [ ! -f "$BIN_TARGET" ] || cp -p "$BIN_TARGET" "$backup/binary"
    [ ! -f "$SERVICE_FILE" ] || cp -p "$SERVICE_FILE" "$backup/service"
    if service_exists; then existed=1; fi
    rollback() {
        local result=$?
        trap - ERR
        echo "ERROR: Installation failed. Recovery files retained at $backup." >&2
        if [ "$stopped" -eq 1 ]; then
            if service_exists && ! service_stop; then
                echo "ERROR: Cannot stop replacement service; restore manually." >&2
                exit "$result"
            fi
            if [ ! -f "$backup/binary" ]; then
                echo "ERROR: No previous binary; failed installation left stopped." >&2
            elif cp -p "$backup/binary" "$BIN_TARGET" &&
                { [ ! -f "$backup/service" ] || cp -p "$backup/service" "$SERVICE_FILE"; }; then
                if [ "$existed" -eq 1 ]; then
                    if ! service_start || ! wait_for_service; then
                        echo "ERROR: Previous service recovery failed; inspect service logs." >&2
                    else
                        echo "Previous binary restored; installation remains FAILED." >&2
                    fi
                fi
            else
                echo "ERROR: Previous files could not be restored." >&2
            fi
        fi
        exit "$result"
    }
    trap rollback ERR
    if [ "$existed" -eq 1 ]; then service_stop; fi
    stopped=1
    if [ ! -f "$APP_DIR/config.toml" ]; then
        cp "$source_config" "$APP_DIR/config.toml"
    fi
    if [ ! -f "$APP_DIR/license.key" ] && [ -f "$PACKAGE_DIR/license.key" ]; then
        cp "$PACKAGE_DIR/license.key" "$APP_DIR/license.key"
    fi
    chmod 600 "$APP_DIR/config.toml"
    [ ! -f "$APP_DIR/license.key" ] || chmod 600 "$APP_DIR/license.key"
    # Stage beside the destination so replacement is an atomic rename.
    staged=$(trap - ERR; mktemp "$(dirname "$BIN_TARGET")/.omnibridge-binary.XXXXXX")
    cp "$source_binary" "$staged"
    chmod 755 "$staged"
    mv -f "$staged" "$BIN_TARGET"
    cp "$PACKAGE_DIR/installer/$unit" "$SERVICE_FILE"
    chmod 644 "$SERVICE_FILE"
    if [ "$PLATFORM" = "macos" ]; then
        mkdir -p "$LOG_DIR"
        chown root:wheel "$SERVICE_FILE"
    fi
    service_start
    wait_for_service
    echo "Service installed: manager running and HTTP live on port $PORT."
    echo "This does not certify hardware. Recovery files: $backup"
)
