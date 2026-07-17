#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Latte Dock contributors
# SPDX-FileCopyrightText: 2026 Bree Spektor
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Run a command under a throwaway nested kwin_wayland session so it gets a
# Vulkan-capable wayland QPA (QVulkanInstance needs platform glue the
# offscreen QPA lacks; the probe's window still never maps).
#
# The upstream harness used kwin's --exit-with-session to launch the command;
# on the pinned kwin 6.6.5 that never starts the session app (verified with a
# trivial script: kwin comes up, the wayland socket appears, the app never
# runs). So this wrapper backgrounds kwin on a private socket in a private
# XDG_RUNTIME_DIR, waits for the socket, runs the command directly (it
# inherits the caller's env, no generated session script needed), then tears
# kwin down. Exit code is the command's own.
#
# Lavapipe-ONLY, by the adoption plan's hard constraint (pure CPU, VM-safe):
# the upstream harness's dgpu device mode and its hardware-pinning env are
# deliberately not ported. SCENEPROBE_DEVICE stays as the golden-set name
# ("lavapipe" is the only value); anything else is refused loudly.
#
# ICD and validation layer come from the flake pin (devShell exports
# LATTE_VULKAN_LAVAPIPE_ICD and LATTE_VK_LAYER_PATH), never from the host's
# /run/opengl-driver - goldens must be blessed against the exact Mesa CI runs.
set -u

DEV="${SCENEPROBE_DEVICE:-lavapipe}"
[ "$DEV" = "lavapipe" ] || { echo "unsupported SCENEPROBE_DEVICE '$DEV': this harness is lavapipe-only (pure-CPU constraint)" >&2; exit 2; }

ICD="${LATTE_VULKAN_LAVAPIPE_ICD:-}"
[ -n "$ICD" ] && [ -f "$ICD" ] || { echo "lavapipe ICD not found (LATTE_VULKAN_LAVAPIPE_ICD unset or missing; run inside the flake devShell)" >&2; exit 2; }
LAYERS="${LATTE_VK_LAYER_PATH:-}"
[ -n "$LAYERS" ] && [ -d "$LAYERS" ] || { echo "validation layer manifests not found (LATTE_VK_LAYER_PATH unset or missing; run inside the flake devShell)" >&2; exit 2; }

RT="$(mktemp -d /tmp/sceneprobe-xdg.XXXXXX)"; chmod 700 "$RT"
KWINLOG="$RT/kwin.log"
SOCK=sceneprobe-wl

cleanup() {
    [ -n "${KWINPID:-}" ] && kill "$KWINPID" 2>/dev/null && wait "$KWINPID" 2>/dev/null
    # the xdg-desktop-portal the nested bus activates FUSE-mounts $RT/doc;
    # unmount before removing or the rm leaves the mountpoint behind
    fusermount3 -u "$RT/doc" 2>/dev/null || fusermount -u "$RT/doc" 2>/dev/null || true
    rm -rf "$RT" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

XDG_RUNTIME_DIR="$RT" KWIN_WAYLAND_NO_PERMISSION_CHECKS=1 \
  dbus-run-session -- kwin_wayland --virtual --width 256 --height 256 \
  --no-lockscreen --socket "$SOCK" >"$KWINLOG" 2>&1 &
KWINPID=$!

for _ in $(seq 1 150); do
    [ -S "$RT/$SOCK" ] && break
    kill -0 "$KWINPID" 2>/dev/null || break
    sleep 0.1
done
if [ ! -S "$RT/$SOCK" ]; then
    echo "nested kwin_wayland never brought up its socket; its log:" >&2
    cat "$KWINLOG" >&2
    exit 2
fi

# LP_NUM_THREADS=0 disables llvmpipe's threaded rasterizer, which is what
# makes lavapipe output bit-reproducible (the {0,0} golden tier depends on it).
env QT_QPA_PLATFORM=wayland WAYLAND_DISPLAY="$SOCK" XDG_RUNTIME_DIR="$RT" \
    QSG_RHI_BACKEND=vulkan LP_NUM_THREADS=0 \
    VK_ICD_FILENAMES="$ICD" VK_LAYER_PATH="$LAYERS" \
    timeout 90 "$@"
ec=$?

exit "$ec"
