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

readonly before_ids="$(snapshot | python3 -c '
import json, sys
print(" ".join(str(v["persistentDockId"]) for v in json.load(sys.stdin)["views"]))
')"

created_view_ids() {
    snapshot 2>/dev/null | python3 -c '
import json, sys
before = {int(value) for value in sys.argv[1].split()}
for view in json.load(sys.stdin)["views"]:
    if view["persistentDockId"] not in before:
        print(view["persistentDockId"])
' "$before_ids"
}

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
    local created_id removed=false
    e2e_call setViewEditMode ub "$view_a" false >/dev/null 2>&1 || true
    e2e_call setViewPlacement uiii "$view_a" "$screen_a" \
        "$(edge_value "$edge_a")" "$(alignment_value "$alignment_a")" \
        >/dev/null 2>&1 || true
    wait_for_view_state "$view_a" "$edge_a" False >/dev/null 2>&1 || true
    while read -r created_id; do
        [[ -n "$created_id" ]] || continue
        e2e_call setViewEditMode ub "$created_id" false >/dev/null 2>&1 || true
        #! Removal immediately tombstones persistent state; stopping the
        #! throwaway dock commits it without waiting through Plasma's Undo
        #! notification window. The next recipe therefore restarts from the
        #! original topology.
        e2e_call removeView u "$created_id" >/dev/null 2>&1 || true
        removed=true
    done < <(created_view_ids || true)
    if [[ "$removed" == true ]]; then
        sleep 1
    fi
    e2e_dock_stop >/dev/null 2>&1 || true
}
trap restore EXIT

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

canvas_window() {
    local expected="$1" ex ey ew eh i rows count
    read -r ex ey ew eh <<< "$expected"
    for i in $(seq 1 20); do
        rows="$(e2e_kwin_js "const matches = workspace.windowList().filter(w =>
            String(w.resourceClass) === 'latte-dock'
            && w.layer === 3
            && Math.round(w.frameGeometry.width) === $ew
            && Math.round(w.frameGeometry.height) === $eh);
        for (const w of matches) {
            print('@TAG@|' + w.internalId
                + ' ' + Math.round(w.frameGeometry.x)
                + ' ' + Math.round(w.frameGeometry.y)
                + ' ' + Math.round(w.frameGeometry.width)
                + ' ' + Math.round(w.frameGeometry.height));
        }")"
        count="$(grep -c . <<< "$rows")"
        if [[ "$count" -eq 1 ]]; then
            echo "$rows"
            return 0
        fi
        sleep 0.25
    done
    return 1
}

assert_canvas_agrees() {
    local view="$1" pass="$2" expected mapped id x y width height
    expected="$(canvas_geometry "$view")"
    mapped="$(canvas_window "$expected")" \
        || e2e_fail "$pass: expected exactly one compositor canvas with reported size $expected"
    read -r id x y width height <<< "$mapped"
    last_canvas_window_id="$id"
    [[ "$x $y $width $height" == "$expected" ]] \
        || e2e_fail "$pass: canvas $id rendered at $x $y $width $height but Latte reported $expected"
    echo "$pass: canvas $id and reported geometry agree at $x $y $width $height"
}

canvas_a="$(canvas_geometry "$view_a")"
canvas_b="$(canvas_geometry "$view_b")"
[[ "$canvas_a" == "$canvas_b" ]] \
    || e2e_fail "same-edge peers do not share the cache-key geometry: $canvas_a versus $canvas_b"
echo "same-edge peers share canvas geometry $canvas_a"

last_canvas_window_id=""
e2e_call setViewEditMode ub "$view_a" true >/dev/null
wait_for_view_state "$view_a" left True || e2e_fail "first dock's edit session did not open"
assert_canvas_agrees "$view_a" "first mapping"
first_canvas_window_id="$last_canvas_window_id"

#! Retarget the still-shared chrome directly to a second dock with the same
#! canvas rectangle. The handoff closes the old presentation, clears generic
#! layer placement, then maps the same CanvasConfigView for view_b.
e2e_call setViewEditMode ub "$view_b" true >/dev/null
wait_for_view_state "$view_b" left True || e2e_fail "second dock's edit session did not open"
wait_for_view_state "$view_a" left False || e2e_fail "first dock stayed in edit mode after retarget"
assert_canvas_agrees "$view_b" "same-edge retarget"
[[ "$last_canvas_window_id" != "$first_canvas_window_id" ]] \
    || e2e_fail "same canvas surface $last_canvas_window_id survived a retarget that must remap it"
echo "canvas generation changed from $first_canvas_window_id to $last_canvas_window_id"

echo "vertical edit canvas preserves its edge placement across same-edge chrome retarget"
