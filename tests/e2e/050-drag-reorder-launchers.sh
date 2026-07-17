#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Latte Dock contributors
# SPDX-FileCopyrightText: 2026 Bree Spektor
# SPDX-License-Identifier: GPL-2.0-or-later
# e2e-mode: nested-only
#
# EX-14 live check 1 (docs/agent-logs/EX-14.md): drag-reorder a pinned
# launcher - press on the second launcher, GLIDE along the dock axis past
# the third (small steps; jumps miss parabolic-shifted icons, the
# documented trap fakepointer's interpolated drag exists for), release.
# The launcher order must flip in the live readback (viewTasksData), reach
# the launchers config entry once the dock stops, and SURVIVE a restart.
set -uo pipefail
source "${E2E_REPO:?run through scripts/run-e2e.sh}/tests/e2e/lib.sh"

view="$(e2e_tasks_view)" || e2e_fail "no tasks view"

order() {
    e2e_json viewTasksData u "$view" | python3 -c '
import json, sys
print(" ".join(t["launcherUrl"] for t in json.load(sys.stdin)))'
}

#! preconditions: pure launchers (a window task would reflow mid-drag),
#! at least three of them
mapfile -t launchers < <(order | tr ' ' '\n')
[[ "${#launchers[@]}" -ge 3 ]] || e2e_fail "need >=3 pinned launchers, have ${#launchers[@]}"
e2e_json viewTasksData u "$view" | grep -q '"isLauncher":false' && e2e_fail "window tasks present; this recipe needs a launchers-only bar"

#! the launchers config entry (key name carries the synced-group id, so it
#! is discovered, not assumed) - the persistence witness after the stop
tasks_applet="$(e2e_json viewAppletsData u "$view" | python3 -c '
import json, sys
print(next(a["id"] for a in json.load(sys.stdin) if a["plugin"] == "org.kde.latte.plasmoid"))')"
launchers_key="$(awk -v id="$view" -v ap="$tasks_applet" '
    $0 == "[Containments][" id "][Applets][" ap "][Configuration][General]" {f=1; next}
    /^\[/ {f=0}
    f && /^launchers[0-9]*=/ {split($0, kv, "="); print kv[1]; exit}' "$E2E_LAYOUT")"
[[ -n "$launchers_key" ]] || e2e_fail "no launchers entry found in the layout for applet $tasks_applet"
orig_launchers="$(kreadconfig6 --file "$E2E_LAYOUT" --group Containments --group "$view" \
    --group Applets --group "$tasks_applet" --group Configuration --group General --key "$launchers_key")"

restore_config() {
    e2e_dock_stop >/dev/null 2>&1 || true
    kwriteconfig6 --file "$E2E_LAYOUT" --group Containments --group "$view" \
        --group Applets --group "$tasks_applet" --group Configuration --group General \
        --key "$launchers_key" "$orig_launchers"
}
trap restore_config EXIT

#! the zoom stays ON, deliberately: with zoomLevel=0 the auto-sized bar
#! keeps trailing space inside the tasks applet and the even-division
#! center model breaks (calibrated: the press landed a whole slot over);
#! at the default zoom the division matches the rendered icons within a
#! few px and the drag stream itself handles the parabolic shifts.

before="$(order)"
echo "before: $before"
expected="${launchers[0]} ${launchers[2]} ${launchers[1]}"
for ((i = 3; i < ${#launchers[@]}; i++)); do expected+=" ${launchers[$i]}"; done

# attempt_drag: derive the launcher centers by PIXEL CALIBRATION at drag
# time - the surface's true x cannot be trusted from any report (the
# window drifts from viewsData's implied origin, re-anchors on clock
# minute ticks, and the sidebar's same-sized window makes the compositor
# dump ambiguous; all three bit during calibration). The spotify icon is a
# saturated green disc unique in the bar, so a screenshot row through the
# icon centers gives its REAL center, and every other center derives from
# it by the even-slot model.
spotify_idx="$(e2e_json viewTasksData u "$view" | python3 -c '
import json, sys
tasks = json.load(sys.stdin)
print(next(i for i, t in enumerate(tasks) if t["appId"] == "spotify.desktop"))' 2>/dev/null)" \
    || e2e_fail "pixel calibration needs the spotify launcher in the bar (my staged config carries it)"

attempt_drag() {
    local model shot row c1x c1y c2x c2y slot
    model="$(
        { e2e_json viewsData; e2e_json viewAppletsData u "$view"; e2e_json viewTasksData u "$view"; } | python3 -c "
import json, sys
views, applets, tasks = (json.loads(line) for line in sys.stdin)
view = next(v for v in views if v['containmentId'] == $view)
ax, ay = view['absoluteGeometry'][:2]
lx, ly = view['localGeometry'][:2]
oy = ay - ly
applet = next(a for a in applets if a['plugin'] == 'org.kde.latte.plasmoid')
px, py, pw, ph = applet['geometry']
n = len(tasks)
print(int(ax - lx + px), int(oy + py + ph / 2), int(pw / n), n)
")"
    read -r rowx cy slot ntasks <<< "$model"

    shot="$(mktemp --suffix=.png)"
    e2e_screenshot "$shot" || e2e_fail "calibration screenshot failed"
    read -r c1x c2x <<< "$(
        magick "$shot" -crop "1600x1+0+$cy" -depth 8 txt:- | python3 -c "
import re, sys
greens = [int(m.group(1)) for m in
          (re.match(r'(\d+),0: \((\d+),(\d+),(\d+)', line) for line in sys.stdin)
          if m and int(m.group(3)) > 150 and int(m.group(2)) < 120 and int(m.group(4)) < 140]
if not greens or max(greens) - min(greens) > 80:
    sys.exit('no clean spotify-green run on the icon row (got %d green px)' % len(greens))
spotify = (min(greens) + max(greens)) / 2
slot = $slot
c = lambda i: int(spotify + (i - $spotify_idx) * slot)
print(c(1), c(2))
")" || e2e_fail "pixel calibration failed"
    rm -f "$shot"
    c1y="$cy"; c2y="$cy"

    #! settle ONTO the launcher first (glide, not jump - the vehicle's
    #! enter race), then press and glide to launcher 3's rest center; the
    #! model reorders LIVE while the drag crosses a neighbor
    #! (decideTasksDragMove's MoveDragSource), so releasing at the rest
    #! center means exactly ONE crossing - releasing half a slot further
    #! rides into the next neighbor and swaps twice (calibrated). The
    #! interpolated drag stream (24 steps per waypoint pair, ~12ms apart)
    #! keeps every step small for the live hit testing.
    "$E2E_FAKEPOINTER" move "$c1x" 500; sleep 0.3
    "$E2E_FAKEPOINTER" glide "$c1x" 500 "$c1x" "$c1y"; sleep 0.4
    "$E2E_FAKEPOINTER" drag "$c1x" "$c1y" \
        $(( (c1x + c2x) / 2 )) "$c1y" \
        "$c2x" "$c2y"
    sleep 2
}

reset_order() {
    e2e_dock_stop >/dev/null || return 1
    kwriteconfig6 --file "$E2E_LAYOUT" --group Containments --group "$view" \
        --group Applets --group "$tasks_applet" --group Configuration --group General \
        --key "$launchers_key" "$orig_launchers"
    e2e_dock_start >/dev/null
}

after=""
for attempt in 1 2 3; do
    attempt_drag
    after="$(order)"
    [[ "$after" == "$expected" ]] && break
    if [[ "$after" != "$before" ]]; then
        #! an adjacent pair moved, just not the intended one: the press
        #! landed a slot over on stale geometry - reset and re-aim
        echo "  (attempt $attempt reordered the wrong pair: $after - resetting)"
        reset_order || e2e_fail "could not reset the launcher order between attempts"
    else
        echo "  (attempt $attempt did not reorder anything, retrying)"
    fi
done
echo "after:  $after"
[[ "$after" == "$expected" ]] || e2e_fail "drag did not swap launchers 2 and 3 in 3 attempts (expected: $expected)"
echo "live order flipped (launcher 2 dropped past launcher 3)"

#! the config witness needs the flush a clean stop guarantees
e2e_dock_stop || e2e_fail "no clean stop to flush the launcher order"
persisted="$(kreadconfig6 --file "$E2E_LAYOUT" --group Containments --group "$view" \
    --group Applets --group "$tasks_applet" --group Configuration --group General --key "$launchers_key")"
persisted_ids="$(tr ',' ' ' <<< "$persisted")"
[[ "$persisted_ids" == "$expected" ]] || e2e_fail "config order after stop: '$persisted' (expected '$expected')"
echo "config entry $launchers_key carries the new order"

#! and the new order must survive a restart
e2e_dock_start || e2e_fail "dock did not come back for the persistence check"
final="$(order)"
[[ "$final" == "$expected" ]] || e2e_fail "order did not survive the restart (got: $final)"
echo "reorder survived the dock restart"
