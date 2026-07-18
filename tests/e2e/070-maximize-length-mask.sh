#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Latte Dock contributors
# SPDX-FileCopyrightText: 2026 Bree Spektor
# SPDX-License-Identifier: GPL-2.0-or-later
# e2e-mode: nested-only
#
# The maximize-length repaint fix (app/view/inputmaskflush.h, Effects). On Qt6
# wayland a masked dock's window mask clips each frame's submitted damage, so
# when the input band SHRINKS the vacated edge pixels' clearing damage is
# dropped and the compositor keeps a stale frosted band. The fix keeps the
# WINDOW mask at the union across the shrink and collapses it back to the band
# once the band settles (~100ms, a coalescing timer in Effects).
#
# The motivating trigger is "maximize panel length in presence of maximized
# windows" (maximizeWhenMaximized): a maximized client overrides the dock's
# maxLength to full width, and un-maximizing drops it back, shrinking the band.
# That trigger is NOT drivable in the nested vehicle - existsWindowMaximized
# never flips here (this vehicle's kwin does not surface the plasma
# window-management maximized state to Latte; a konsole cycled maximized <->
# normal left the band unchanged, measured). So this recipe drives the IDENTICAL
# band-shrink path through the exact quantity maximizeWhenMaximized overrides -
# maxLength - via the edit-mode length ruler, below the applet extent so the
# band actually shrinks, and asserts per-view over D-Bus that after each shrink
# settles the applied window mask (appliedInputRegionRects) has COLLAPSED back
# to the band (applied == input). A settle collapse that failed to fire would
# leave the applied mask stuck at the pre-shrink union (applied wider than
# input) and fail here.
#
# The ~100ms union-hold DURING each shrink is below D-Bus round-trip latency
# (rapid sampling right after a detent never catches it, measured), so it is
# not asserted here; its tripwire is the pure-core unit test inputmaskflushtest
# (a naive setMask(band) aborts on the shrink invariant) and the live
# union-then-collapse is recorded in
# docs/agent-logs/2026-07-18-maximize-length-repaint.md. The "no frosted band"
# pixel confirmation on the real maximize-length feature is a desk-check (same
# ledger).
set -uo pipefail
source "${E2E_REPO:?run through scripts/run-e2e.sh}/tests/e2e/lib.sh"

# per-view applied and input band widths (0 when the region is empty/cleared)
mask_widths() {
    e2e_json viewsData | python3 -c "
import json, sys
m = [x for x in json.load(sys.stdin) if x['containmentId'] == $1]
if not m:
    print(0, 0); sys.exit()
v = m[0]
a = (v.get('appliedInputRegionRects') or [[0, 0, 0, 0]])[0][2]
i = (v.get('inputRegionRects') or [[0, 0, 0, 0]])[0][2]
print(a, i)
"
}

# widest bottom masked dock (a dock realises its length through the mask; a
# plasma panel has none, and the ruler lives on horizontal docks)
view="$(e2e_json viewsData | python3 -c '
import json, sys
vs = [v for v in json.load(sys.stdin)
      if v["type"] == "dock" and v["edge"] == "bottom" and not v["isHidden"]]
vs.sort(key=lambda v: -v["absoluteGeometry"][2])
print(vs[0]["containmentId"] if vs else "")
')"
[[ -n "$view" ]] || e2e_fail "no masked bottom dock to drive"

read -r sx sy sw sh <<< "$(e2e_view_field "$view" '"%d %d %d %d" % tuple(v["absoluteGeometry"])')"
read -r scw <<< "$(e2e_view_field "$view" 'v["screenGeometry"][2]')"

read -r rest_a rest_i <<< "$(mask_widths "$view")"
echo "view $view rest: applied=${rest_a} input=${rest_i} (screen ${scw}px)"
[[ "$rest_a" -gt 0 ]] || e2e_fail "rest applied mask is empty (no band to shrink)"
[[ "$rest_a" == "$rest_i" ]] || e2e_fail "rest applied ($rest_a) != input ($rest_i): not collapsed at rest"

layout="$E2E_LAYOUT"
orig_maxl="$(kreadconfig6 --file "$layout" --group Containments --group "$view" --group General --key maxLength 2>/dev/null || true)"
in_edit=0
restore() {
    (( in_edit == 1 )) && { e2e_call setViewEditMode ub "$view" false >/dev/null 2>&1 || true; sleep 1; }
    e2e_dock_stop >/dev/null 2>&1 || true
    if [[ -n "$orig_maxl" ]]; then
        kwriteconfig6 --file "$layout" --group Containments --group "$view" --group General --key maxLength "$orig_maxl"
    else
        kwriteconfig6 --file "$layout" --group Containments --group "$view" --group General --key maxLength --delete
    fi
}
trap restore EXIT

cur_maxl() {
    local v
    v="$(kreadconfig6 --file "$layout" --group Containments --group "$view" --group General --key maxLength)"
    v="${v%.*}"; echo "${v:-100}"
}

#! enter edit mode (the length ruler only exists there); the canvas is the
#! screen-wide thin latte window that maps on entry
windows_before="$(e2e_dumpwins | grep '|latte-dock|' | sort)"
"$E2E_FAKEPOINTER" move 800 400; sleep 0.5
e2e_call setViewEditMode ub "$view" true >/dev/null
in_edit=1
sleep 3
canvas="$(comm -13 <(echo "$windows_before") <(e2e_dumpwins | grep '|latte-dock|' | sort) | awk -F'|' -v scw="$scw" '
    { split($4, g, " "); split(g[1], pos, ","); split(g[2], size, "x");
      if (size[1] == scw && size[2] < 300) { printf "%d %d %d %d\n", pos[1], pos[2], size[1], size[2]; exit } }')"
[[ -n "$canvas" ]] || e2e_fail "no canvas window mapped for edit mode"
read -r cx cy cw ch <<< "$canvas"
rx=$(( sx + sw / 2 ))     #! ruler center, over the strip
ry=$(( cy + 7 ))          #! bottom dock: ruler on the canvas' top rows

# one down-detent that actually lands (retries; a lost axis event is common in
# the nested compositor), leaving the pointer off the ruler
down_detent() {
    local before="$1" attempt i now
    for attempt in 1 2 3 4 5; do
        "$E2E_FAKEPOINTER" scroll "$rx" "$ry" -1 100
        "$E2E_FAKEPOINTER" move "$rx" 650
        for i in 1 2 3 4 5 6; do
            sleep 0.5
            now="$(cur_maxl)"
            [[ "$now" != "$before" ]] && { echo "$now"; return 0; }
        done
    done
    echo "$before"
    return 1
}

#! wheel maxLength down past the applet extent so the band shrinks, checking
#! after every settled detent that the applied mask collapsed back to the band
prev_band="$rest_a"
shrinks=0
last_maxl="$(cur_maxl)"
for step in $(seq 1 16); do
    new_maxl="$(down_detent "$last_maxl")" || e2e_fail "ruler down-detent $step never landed"
    last_maxl="$new_maxl"
    sleep 1.0   #! let the settle collapse run
    read -r aw iw <<< "$(mask_widths "$view")"
    [[ "$aw" == "$iw" ]] || e2e_fail "after shrink to maxLength ${new_maxl}: applied ($aw) != input ($iw) - mask stuck at the wide union, settle collapse failed"
    if (( aw < prev_band )); then
        shrinks=$((shrinks + 1))
        echo "maxLength ${new_maxl}: band ${prev_band} -> ${aw}, applied collapsed to input (${aw})"
    fi
    prev_band="$aw"
    (( aw * 100 <= rest_a * 70 )) && break   #! a clear, multi-step shrink is enough
done

(( shrinks >= 2 )) || e2e_fail "the band never shrank across ${shrinks} step(s) (ruler did not drive a length reduction below the applet extent)"
(( prev_band * 100 <= rest_a * 80 )) || e2e_fail "band ${prev_band} did not shrink meaningfully below rest ${rest_a}"

e2e_call setViewEditMode ub "$view" false >/dev/null
in_edit=0
sleep 2

#! back out of edit mode the mask stays consistent (applied still collapsed)
read -r fin_a fin_i <<< "$(mask_widths "$view")"
[[ "$fin_a" == "$fin_i" ]] || e2e_fail "after leaving edit mode: applied ($fin_a) != input ($fin_i)"

echo "maximize-length path: band shrank ${rest_a} -> ${prev_band} over ${shrinks} steps, applied window mask collapsed to the band at every step"
