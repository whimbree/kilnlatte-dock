#!/usr/bin/env bash
# Restart the staged dock reliably (porting plan live-verification cadence).
#
# Instances whose launching terminal died can end up SIGSTOPped (state T).
# A stopped process never runs its SIGTERM handler, so a plain pkill leaves
# it alive forever and the next launch silently stacks a second instance -
# three docks fighting over layer surfaces was observed on 2026-07-10.
# TERM first, then CONT so the pending TERM is delivered, escalate to KILL,
# and refuse to start while any instance survives.
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"

if pgrep -x latte-dock >/dev/null; then
    pkill -TERM -x latte-dock || true
    pkill -CONT -x latte-dock || true
    for _ in $(seq 1 50); do
        pgrep -x latte-dock >/dev/null || break
        sleep 0.2
    done
fi

if pgrep -x latte-dock >/dev/null; then
    echo "latte-dock survived SIGTERM, sending SIGKILL:" >&2
    pgrep -ax latte-dock >&2
    pkill -KILL -x latte-dock
    sleep 1
fi

if pgrep -x latte-dock >/dev/null; then
    echo "latte-dock still alive after SIGKILL, refusing to stack another instance" >&2
    exit 1
fi

# setsid + closed stdin: no controlling terminal, so the dock can never be
# stopped or hung up by its launching terminal going away.
exec setsid nix develop "$repo" -c "$repo/scripts/run-staged.sh" "$@" </dev/null
