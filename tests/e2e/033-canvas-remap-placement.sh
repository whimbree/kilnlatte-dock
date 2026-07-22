#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Bree Spektor
# SPDX-FileCopyrightText: 2026 Latte Dock contributors
# SPDX-License-Identifier: GPL-2.0-or-later
# e2e-mode: nested-only
#
# The settings chrome is shared across docks. Retargeting it while hidden runs
# the generic config-window setup, which deliberately clears the old layer
# anchors before the concrete window reapplies its placement. Two left docks on
# the same output have the same canvas rectangle, so CanvasConfigView's old
# geometry-only early return mistook the second dock for "already placed" and
# skipped that reapply. KWin then centred the unanchored vertical canvas across
# the output even though Latte still reported the correct left-edge
# canvasGeometry. Exercise that exact same-edge retarget boundary and compare
# compositor truth with the reported rect.
set -uo pipefail
source "${E2E_REPO:?run through scripts/run-e2e.sh}/tests/e2e/lib.sh"

snapshot() { e2e_json dockSystemData; }

readonly view_a="$(snapshot | python3 -c '
import json, sys
views = [v for v in json.load(sys.stdin)["views"]
         if v["type"] == "dock" and v["relationship"] == "independent"]
views.sort(key=lambda v: v["persistentDockId"])
print(views[0]["persistentDockId"] if views else "")
')"
[[ -n "$view_a" ]] || e2e_fail "no independent dock is available for the shared-canvas retarget test"

placement_record() {
    local view="$1"
    snapshot | python3 -c "
import json, sys
view = next(v for v in json.load(sys.stdin)['views'] if v['persistentDockId'] == $view)
print(view['screenId'], view['edge'], view['alignment'])
"
}

read -r screen_a edge_a alignment_a <<< "$(placement_record "$view_a")"
view_b=""

edge_value() {
    case "$1" in
        top) echo 3 ;;
        bottom) echo 4 ;;
        left) echo 5 ;;
        right) echo 6 ;;
        *) e2e_fail "cannot restore unknown edge '$1'" ;;
    esac
}

alignment_value() {
    case "$1" in
        center) echo 0 ;;
        left) echo 1 ;;
        right) echo 2 ;;
        top) echo 3 ;;
        bottom) echo 4 ;;
        justify) echo 10 ;;
        *) e2e_fail "cannot restore unknown alignment '$1'" ;;
    esac
}

wait_for_view_state() {
    local view="$1" edge="$2" editing="$3" i
    for i in $(seq 1 60); do
        if snapshot | python3 -c "
import json, sys
view = next((v for v in json.load(sys.stdin)['views']
             if v['persistentDockId'] == $view), None)
sys.exit(0 if view and view['edge'] == '$edge'
         and view['editMode'] is $editing and view['geometrySettled'] else 1)
"; then
            return 0
        fi
        sleep 0.5
    done
    return 1
}

restore() {
    e2e_call setViewEditMode ub "$view_a" false >/dev/null 2>&1 || true
    if [[ -n "$view_b" ]]; then
        e2e_call setViewEditMode ub "$view_b" false >/dev/null 2>&1 || true
    fi
    e2e_call setViewPlacement uiii "$view_a" "$screen_a" \
        "$(edge_value "$edge_a")" "$(alignment_value "$alignment_a")" \
        >/dev/null 2>&1 || true
    wait_for_view_state "$view_a" "$edge_a" False >/dev/null 2>&1 || true
    if [[ -n "$view_b" ]]; then
        #! Removal immediately tombstones persistent state; stopping the
        #! throwaway dock commits it without waiting through Plasma's Undo
        #! notification window. The next recipe therefore restarts from the
        #! original topology.
        e2e_call removeView u "$view_b" >/dev/null 2>&1 || true
        sleep 1
    fi
    e2e_dock_stop >/dev/null 2>&1 || true
}
trap restore EXIT

before_ids="$(snapshot | python3 -c '
import json, sys
print(" ".join(str(v["persistentDockId"]) for v in json.load(sys.stdin)["views"]))
')"
e2e_call duplicateView u "$view_a" >/dev/null
for i in $(seq 1 60); do
    view_b="$(snapshot | python3 -c '
import json, sys
before = {int(value) for value in sys.argv[1].split()}
created = [v for v in json.load(sys.stdin)["views"]
           if v["persistentDockId"] not in before
           and v["relationship"] == "independent"]
print(created[0]["persistentDockId"] if len(created) == 1 else "")
' "$before_ids")"
    [[ -n "$view_b" ]] && break
    sleep 0.5
done
[[ -n "$view_b" ]] || e2e_fail "Duplicate Dock did not create one independent retarget peer"

e2e_call setViewEditMode ub "$view_a" false >/dev/null 2>&1 || true
e2e_call setViewEditMode ub "$view_b" false >/dev/null 2>&1 || true
e2e_call setViewPlacement uiii "$view_a" "$screen_a" 5 0 >/dev/null
e2e_call setViewPlacement uiii "$view_b" "$screen_a" 5 0 >/dev/null
wait_for_view_state "$view_a" left False \
    || e2e_fail "dock $view_a did not settle on the left edge"
wait_for_view_state "$view_b" left False \
    || e2e_fail "dock $view_b did not settle beside dock $view_a"

canvas_geometry() {
    local view="$1"
    snapshot | python3 -c "
import json, sys
view = next(v for v in json.load(sys.stdin)['views'] if v['persistentDockId'] == $view)
print(*view['canvasGeometry'])
"
}

mapped_canvas_geometry() {
    local expected="$1" ex ey ew eh i mapped
    read -r ex ey ew eh <<< "$expected"
    for i in $(seq 1 20); do
        mapped="$(e2e_dumpwins | awk -F'|' -v ew="$ew" -v eh="$eh" '
            $2 ~ /latte-dock/ && $6 == "layer=3" {
                split($4, geometry, " ");
                split(geometry[1], position, ",");
                split(geometry[2], size, "x");
                if (int(size[1] + 0.5) == ew && int(size[2] + 0.5) == eh) {
                    printf "%d %d %d %d\n", int(position[1] + 0.5), int(position[2] + 0.5),
                           int(size[1] + 0.5), int(size[2] + 0.5);
                    exit;
                }
            }')"
        if [[ -n "$mapped" ]]; then
            echo "$mapped"
            return 0
        fi
        sleep 0.25
    done
    return 1
}

assert_canvas_agrees() {
    local view="$1" pass="$2" expected mapped
    expected="$(canvas_geometry "$view")"
    mapped="$(mapped_canvas_geometry "$expected")" \
        || e2e_fail "$pass: no compositor canvas matches reported size $expected"
    [[ "$mapped" == "$expected" ]] \
        || e2e_fail "$pass: canvas rendered at $mapped but Latte reported $expected"
    echo "$pass: canvas renderer and reported geometry agree at $mapped"
}

e2e_call setViewEditMode ub "$view_a" true >/dev/null
wait_for_view_state "$view_a" left True || e2e_fail "first dock's edit session did not open"
assert_canvas_agrees "$view_a" "first mapping"

#! Retarget the still-shared chrome directly to a second dock with the same
#! canvas rectangle. The handoff closes the old presentation, clears generic
#! layer placement, then maps the same CanvasConfigView for view_b.
e2e_call setViewEditMode ub "$view_b" true >/dev/null
wait_for_view_state "$view_b" left True || e2e_fail "second dock's edit session did not open"
wait_for_view_state "$view_a" left False || e2e_fail "first dock stayed in edit mode after retarget"
assert_canvas_agrees "$view_b" "same-edge retarget"

echo "vertical edit canvas preserves its edge placement across same-edge chrome retarget"
