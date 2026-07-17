#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Latte Dock contributors
# SPDX-FileCopyrightText: 2026 Bree Spektor
# SPDX-License-Identifier: GPL-2.0-or-later
# e2e-mode: nested-only
#
# EX-15 live check 2 (docs/agent-logs/EX-15.md): with scrollAction=Desktops,
# a wheel detent over EMPTY dock area switches the virtual desktop - one
# ADJACENT switch per detent (the EnvironmentActions cutover through
# LatteCore.WheelStepper, SignedExtreme pick, threshold 80). Three desktops
# are used so an overshoot (two switches from one detent) is detectable.
# fakepointer detents are 120 angleDelta units, so the sub-threshold half of
# the contract stays with the unit tests (wheelaccumulatortest).
#
# VEHICLE LIMITATION, established with dock-side instrumentation
# (2026-07-17, this unit's ledger): the nested kwin stops delivering
# pointer/wheel events to the dock's layer surface after a desktop switch -
# repeated wheels deliver fine as long as no switch happens (verified 3-in-a-
# row), the first real switch kills delivery, motion does not restore it, and
# the dock's input regions stay intact throughout (viewsData readback), so
# the fault is compositor-side input-focus bookkeeping under fake input, not
# the dock. The recipe therefore restarts the dock between the two
# directions (the only reliable delivery reset found) and retries each
# detent's delivery; the ASSERTIONS stay semantic: a delivered detent moves
# to exactly the adjacent desktop.
set -uo pipefail
source "${E2E_REPO:?run through scripts/run-e2e.sh}/tests/e2e/lib.sh"

vdm() { busctl --user "$1" org.kde.KWin /VirtualDesktopManager org.kde.KWin.VirtualDesktopManager "${@:2}"; }
desktop_count() { vdm get-property count | awk '{print $2}'; }
current_desktop() { vdm get-property current | awk '{print $2}' | tr -d '"'; }
desktop_id() { vdm get-property desktops | grep -oE '"[0-9a-f-]{36}"' | sed -n "${1}p" | tr -d '"'; }

view="$(e2e_tasks_view)" || e2e_fail "no tasks view"

#! preconditions: three desktops (overshoot detection), dock starting on the
#! first; both verified to have taken effect before the dock (re)starts
created=()
while [[ "$(desktop_count)" -lt 3 ]]; do
    n=$(( $(desktop_count) + 1 ))
    vdm call createDesktop us "$((n - 1))" "E2E Desk $n" >/dev/null
    [[ "$(desktop_count)" -eq "$n" ]] || e2e_fail "createDesktop did not take effect"
    created+=("$n")
done
vdm set-property current s "$(desktop_id 1)"

orig_scroll="$(kreadconfig6 --file "$E2E_LAYOUT" --group Containments --group "$view" --group General --key scrollAction)"

cleanup() {
    e2e_dock_stop >/dev/null 2>&1 || true
    if [[ -n "$orig_scroll" ]]; then
        kwriteconfig6 --file "$E2E_LAYOUT" --group Containments --group "$view" --group General --key scrollAction "$orig_scroll"
    else
        kwriteconfig6 --file "$E2E_LAYOUT" --group Containments --group "$view" --group General --key scrollAction --delete
    fi
    local pos
    for pos in "${created[@]}"; do
        vdm call removeDesktop s "$(desktop_id "$pos")" >/dev/null 2>&1 || true
    done
}
trap cleanup EXIT

#! config flip while the dock is STOPPED: scrollAction=1 (ScrollDesktops)
e2e_dock_stop || e2e_fail "could not stop the dock for the config flip"
kwriteconfig6 --file "$E2E_LAYOUT" --group Containments --group "$view" --group General --key scrollAction 1
e2e_dock_start || e2e_fail "dock did not come back after the config flip"

# empty_area_point: the widest strip x-interval not covered by any applet
# (the strip's side margins hit EnvironmentActions; recomputed after every
# dock start because the centered strip drifts with the clock's text width)
empty_area_point() {
    { e2e_json viewsData; e2e_json viewAppletsData u "$view"; } | python3 -c "
import json, sys
views, applets = (json.loads(line) for line in sys.stdin)
view = next(v for v in views if v['containmentId'] == $view)
ax, ay, aw, ah = view['absoluteGeometry']
ox = ax - view['localGeometry'][0]
spans = sorted((ox + g[0], ox + g[0] + g[2]) for g in (a['geometry'] for a in applets))
gaps, cursor = [], ax
for s, e in spans:
    if s > cursor:
        gaps.append((cursor, s))
    cursor = max(cursor, e)
if ax + aw > cursor:
    gaps.append((cursor, ax + aw))
best = max(gaps, key=lambda g: g[1] - g[0], default=(0, 0))
if best[1] - best[0] < 6:
    sys.exit('widest empty-area gap is under 6px: %s' % (gaps,))
print(int((best[0] + best[1]) / 2), int(ay + ah / 2))
"
}

# wheel_switch <detent> <expect-from> <expect-to>: deliver one detent over
# empty dock area (with the enter dance and delivery retries per the header)
# and assert exactly one adjacent switch.
wheel_switch() {
    local detent="$1" from="$2" to="$3" attempt point px py now i
    point="$(empty_area_point)" || e2e_fail "no empty-area point"
    read -r px py <<< "$point"
    for attempt in 1 2 3 4; do
        [[ "$(current_desktop)" == "$from" ]] || e2e_fail "not on the expected start desktop"
        #! settle the pointer OUTSIDE then INSIDE the strip before wheeling:
        #! an axis event racing its own enter never reaches the QML scene
        "$E2E_FAKEPOINTER" move "$px" 500
        sleep 0.3
        "$E2E_FAKEPOINTER" move "$px" "$py"
        sleep 0.6
        "$E2E_FAKEPOINTER" scroll "$px" "$py" "$detent" 100
        for i in 1 2 3 4 5 6; do
            sleep 0.4
            now="$(current_desktop)"
            [[ "$now" != "$from" ]] && break
        done
        if [[ "$now" != "$from" ]]; then
            [[ "$now" == "$to" ]] || e2e_fail "detent $detent overshot: $from -> $now (expected $to)"
            return 0
        fi
        echo "  (detent $detent not delivered on attempt $attempt, retrying)"
    done
    e2e_fail "detent $detent never delivered after 4 attempts (vehicle input-delivery limitation exceeded)"
}

d1="$(desktop_id 1)"; d2="$(desktop_id 2)"

wheel_switch -1 "$d1" "$d2"
echo "down-detent: exactly one adjacent switch (1 -> 2)"

#! delivery reset (see header); the dock restart does not touch desktops
e2e_dock_stop || e2e_fail "could not restart between directions"
e2e_dock_start || e2e_fail "dock did not come back for the up direction"

wheel_switch 1 "$d2" "$d1"
echo "up-detent: exactly one adjacent switch (2 -> 1)"
