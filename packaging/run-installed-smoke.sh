#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Latte Dock contributors
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Packaging smoke test: run the nested 000-smoke e2e recipe against an installed
# /usr/bin/latte-dock (or $LATTE_INSTALLED_DOCK) rather than a worktree build.
# Used by the Tier-1 package recipes after `dnf install` / `apt install`.
set -uo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"

LATTE_INSTALLED_DOCK="${LATTE_INSTALLED_DOCK:-/usr/bin/latte-dock}"
: "${LATTE_QML_MODULE_PATH:?this script needs LATTE_QML_MODULE_PATH (the distro Qt6 QML tree)}"

seeddir="${LATTE_SEED_CONFIG:-/tmp/latte-seed-config}"
E2E_FAKEPOINTER="${E2E_FAKEPOINTER:-/tmp/latte-installed-fakepointer}"

[[ -x "$LATTE_INSTALLED_DOCK" ]] || { echo "not executable: $LATTE_INSTALLED_DOCK"; exit 2; }

source "$repo/scripts/lib-nested-kwin.sh"

# seed a default layout by running the installed dock once in a throwaway
# nested kwin. The default layout is written synchronously at first run.
nested_kwin_prepare
trap 'nested_kwin_cleanup' EXIT
mkdir -p "$NESTED_RT/kwin-config" "$NESTED_RT/kwin-cache"
nested_kwin_env+=(
    WAYLAND_DISPLAY=latte-seed-wl
    XDG_CONFIG_HOME="$NESTED_RT/kwin-config"
    XDG_CACHE_HOME="$NESTED_RT/kwin-cache"
    QT_FORCE_STDERR_LOGGING=1
)
nested_kwin_start 1600 1000 latte-seed-wl || exit 2

export XDG_RUNTIME_DIR="$NESTED_RT"
export WAYLAND_DISPLAY="$NESTED_SOCK"
export DBUS_SESSION_BUS_ADDRESS="$NESTED_BUS"
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
unset DISPLAY XAUTHORITY

rm -rf "$seeddir"
mkdir -p "$seeddir"
seedlog="/tmp/latte-installed-seed-dock.log"
setsid env LATTE_CONFIG_HOME="$seeddir" XDG_CONFIG_HOME="$seeddir" \
    QML2_IMPORT_PATH="$LATTE_QML_MODULE_PATH" \
    QT_QPA_PLATFORM=wayland QT_FORCE_STDERR_LOGGING=1 \
    "$LATTE_INSTALLED_DOCK" -d >"$seedlog" 2>&1 &
dockpid=$!
settled=0
for ((i = 0; i < 90; i++)); do
    state="$(busctl --user call org.kde.lattedock /Latte org.kde.LatteDock lifecycleState 2>/dev/null | awk '{print $2}' || true)"
    if [[ "$state" == '"running"' ]] && ls "$seeddir"/latte/*.layout.latte >/dev/null 2>&1; then
        settled=1; break
    fi
    kill -0 "$dockpid" 2>/dev/null || break
    sleep 1
done
kill -TERM "$dockpid" 2>/dev/null || true
wait "$dockpid" 2>/dev/null || true
if [[ "$settled" != 1 ]]; then
    echo "installed-dock seed failed; log tail:" >&2
    tail -30 "$seedlog" >&2 || true
    exit 2
fi

echo "seed config ready at $seeddir"

# build the fake-input injector if it is not already present. The protocol XML
# location is resolved distro-agnostically via pkg-config where available.
if [[ ! -x "$E2E_FAKEPOINTER" ]]; then
    xml=""
    if command -v pkg-config >/dev/null 2>&1; then
        pkgdir="$(pkg-config --variable=pkgdatadir plasma-wayland-protocols 2>/dev/null || true)"
        [[ -n "$pkgdir" && -f "$pkgdir/fake-input.xml" ]] && xml="$pkgdir/fake-input.xml"
    fi
    [[ -n "$xml" && -f "$xml" ]] || xml="${LATTE_FAKEINPUT_PROTOCOL:-}"
    if [[ -z "$xml" || ! -f "$xml" ]]; then
        for cand in /usr/share/plasma-wayland-protocols/fake-input.xml \
                    /usr/local/share/plasma-wayland-protocols/fake-input.xml; do
            [[ -f "$cand" ]] && { xml="$cand"; break; }
        done
    fi
    [[ -n "$xml" && -f "$xml" ]] || { echo "cannot locate fake-input.xml for fakepointer" >&2; exit 2; }
    gendir="$(dirname "$E2E_FAKEPOINTER")"
    mkdir -p "$gendir"
    wayland-scanner client-header "$xml" "$gendir/fake-input-client-protocol.h"
    wayland-scanner private-code  "$xml" "$gendir/fake-input-protocol.c"
    cc -O2 -o "$E2E_FAKEPOINTER" "$repo/scripts/tools/fakepointer.c" "$gendir/fake-input-protocol.c" \
        -I"$gendir" $(pkg-config --cflags --libs wayland-client xkbcommon)
fi

export E2E_REPO="$repo"
export E2E_BUILD="${E2E_BUILD:-/tmp/latte-installed-fakebuild}"
export E2E_CONFIG_BASE="$seeddir"
export E2E_FAKEPOINTER
export LATTE_INSTALLED_DOCK
export LATTE_QML_MODULE_PATH
mkdir -p "$E2E_BUILD"

exec "$repo/scripts/run-e2e.sh" 000-smoke
