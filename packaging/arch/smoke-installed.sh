#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Latte Dock contributors
# SPDX-FileCopyrightText: 2026 Bree Spektor
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Packaging smoke test for the installed lattedock binary.
#
# Brings up a private nested kwin_wayland compositor, runs the installed
# /usr/bin/latte-dock briefly, asserts it reaches "views settled", and exits
# cleanly on SIGTERM. The compositor runs on lavapipe with software rendering
# so the test is independent of any real GPU.
#
# This script is designed to run in a fresh container layer after the package
# has been installed. Alternatively, set SMOKE_PREFIX to a DESTDIR-staged prefix
# (used by the PKGBUILD check() function) and the script will exercise
# ${SMOKE_PREFIX}/usr/bin/latte-dock while resolving modules and data from the
# staged tree.

# nounset-safe like the reused nested-kwin library; explicit checks below
# carry the failure evidence.
set -uo pipefail

repo="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=../../../scripts/lib-nested-kwin.sh
source "$repo/scripts/lib-nested-kwin.sh"

SMOKE_PREFIX="${SMOKE_PREFIX:-}"
latte_bin="${SMOKE_PREFIX}/usr/bin/latte-dock"
if [[ ! -x "$latte_bin" ]]; then
    echo "smoke-installed: FAIL no installed binary at $latte_bin" >&2
    exit 2
fi
echo "smoke-installed: binary under test: $latte_bin"

# Isolated runtime/config/cache homes. nested_kwin_prepare creates NESTED_RT;
# the dock uses subdirectories of it so the whole session is removed together.
nested_kwin_prepare
trap 'nested_kwin_cleanup' EXIT INT TERM

mkdir -p "$NESTED_RT/kwin-config" "$NESTED_RT/kwin-cache" "$NESTED_RT/latte-config"

nested_kwin_env+=(
    WAYLAND_DISPLAY=latte-smoke-wl
    XDG_CONFIG_HOME="$NESTED_RT/kwin-config"
    XDG_CACHE_HOME="$NESTED_RT/kwin-cache"
    QT_FORCE_STDERR_LOGGING=1
)
nested_kwin_start 1600 1000 latte-smoke-wl || {
    echo "smoke-installed: FAIL nested kwin_wayland never came up" >&2
    tail -40 "$NESTED_KWIN_LOG" >&2 || true
    exit 2
}

export XDG_RUNTIME_DIR="$NESTED_RT"
export WAYLAND_DISPLAY="$NESTED_SOCK"
export DBUS_SESSION_BUS_ADDRESS="$NESTED_BUS"
unset DISPLAY XAUTHORITY

# Make a DESTDIR-staged prefix resolve its own QML modules, plasma packages and
# data. In a real install SMOKE_PREFIX is empty and these collapse to system
# defaults; appending keeps any container-provided paths intact.
export QML2_IMPORT_PATH="${SMOKE_PREFIX}/usr/lib/qt6/qml${QML2_IMPORT_PATH:+:$QML2_IMPORT_PATH}"
export XDG_DATA_DIRS="${SMOKE_PREFIX}/usr/share${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"
export QT_QPA_PLATFORM=wayland
unset QT_PLUGIN_PATH

# Keep staged bin first so a DESTDIR prefix finds its own helper executables,
# while falling back to the system PATH for dbus-activated services.
export PATH="${SMOKE_PREFIX}/usr/bin:${PATH}"

dock_log="$NESTED_RT/dock.log"
dock_pidfile="$NESTED_RT/dock.pid"

echo "smoke-installed: starting installed dock on private bus $DBUS_SESSION_BUS_ADDRESS ..."
setsid env LATTE_CONFIG_HOME="$NESTED_RT/latte-config" \
    "$latte_bin" >"$dock_log" 2>&1 &
echo $! > "$dock_pidfile"

wait_running() {
    local timeout="${1:-120}" i state
    for ((i = 0; i < timeout; i++)); do
        state="$(busctl --user call org.kde.lattedock /Latte org.kde.LatteDock lifecycleState 2>/dev/null | awk '{print $2}')"
        [[ "$state" == '"running"' ]] && return 0
        kill -0 "$(cat "$dock_pidfile")" 2>/dev/null || break
        sleep 1
    done
    echo "smoke-installed: FAIL dock never reached lifecycleState running in ${timeout}s (last state: ${state:-none})" >&2
    return 1
}

wait_settled() {
    local timeout="${1:-120}" i payload previous=
    for ((i = 0; i < timeout; i++)); do
        payload="$(busctl --user call org.kde.lattedock /Latte org.kde.LatteDock viewsData 2>/dev/null)"
        # Views exist, are out of inStartup, and geometry stopped changing
        # (the startup animation keeps moving rects for seconds after inStartup
        # clears; the e2e suite uses the same stable-back-to-back check).
        if [[ -n "$payload" && "$payload" != 's "[]"' && "$payload" != *'inStartup\\":true'* ]]; then
            if [[ "$payload" == "$previous" ]]; then
                return 0
            fi
            previous="$payload"
        fi
        kill -0 "$(cat "$dock_pidfile")" 2>/dev/null || break
        sleep 1
    done
    echo "smoke-installed: FAIL views never settled in ${timeout}s" >&2
    return 1
}

stop_dock() {
    local timeout="${1:-25}" pid i
    pid="$(cat "$dock_pidfile")"
    [[ -n "$pid" ]] || { echo "smoke-installed: no dock pid recorded" >&2; return 1; }
    kill -0 "$pid" 2>/dev/null || { echo "smoke-installed: dock already gone" >&2; return 1; }
    echo "smoke-installed: sending SIGTERM to pid $pid"
    kill -TERM "$pid"
    for ((i = 0; i < timeout * 5; i++)); do
        kill -0 "$pid" 2>/dev/null || return 0
        sleep 0.2
    done
    echo "smoke-installed: FAIL dock (pid $pid) survived SIGTERM for ${timeout}s" >&2
    return 1
}

rc=0
if wait_running && wait_settled; then
    echo "smoke-installed: views settled, requesting clean shutdown..."
    stop_dock || rc=1
else
    rc=1
fi

if [[ "$rc" != 0 ]]; then
    echo "smoke-installed: dock log tail:" >&2
    tail -60 "$dock_log" >&2 || true
fi

if [[ "$rc" == 0 ]]; then
    echo "smoke-installed: PASS (installed binary started, settled, and shut down cleanly)"
fi

exit "$rc"
