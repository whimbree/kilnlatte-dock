#!/usr/bin/env bash
# E2E: gliding the pointer along the dock engages the parabolic pipeline
# and hovering a task maps a preview dialog (the EX-01/02/03 paths end to
# end). Screen-agnostic: derives the widest bottom dock from the window
# dump and glides along it with small steps (jump-clicks land beside
# parabolic-shifted icons; glides are the only honest pointer input).
set -uo pipefail
source "${E2E_REPO:?run through scripts/run-e2e.sh}/tests/e2e/lib.sh"

#! previews need a window-owning task; fresh vehicles carry only launchers.
#! konsole is part of the pinned environment (the vehicle proof's client).
konsole_started=0
if ! e2e_dumpwins | grep -q '|org.kde.konsole|'; then
    setsid konsole >/dev/null 2>&1 &
    konsole_started=$!
    for _ in $(seq 1 30); do
        e2e_dumpwins | grep -q '|org.kde.konsole|' && break
        sleep 1
    done
    e2e_dumpwins | grep -q '|org.kde.konsole|' || e2e_fail "konsole never mapped in the session"
fi
cleanup_konsole() {
    [[ "$konsole_started" != 0 ]] && kill "$konsole_started" 2>/dev/null
}
trap cleanup_konsole EXIT

#! geometry comes from viewsData, not the window dump: dock WINDOWS are
#! larger than the visible strip (shadow/free space) and several views can
#! tie on width, so window-rect picking is ambiguous - the view's
#! absoluteGeometry is the strip itself
tasks_view="$(e2e_tasks_view)" || e2e_fail "no tasks view"
dock="$(e2e_view_field "$tasks_view" '"%d %d %d %d" % tuple(v["absoluteGeometry"])')"
[[ -n "$dock" ]] || e2e_fail "no geometry for view $tasks_view"
read -r dx dy dw dh <<< "$dock"

#! the glide must END on a window-owning task or no preview can appear;
#! resolve the konsole icon's rest position before the pointer distorts
#! anything (e2e_task_center is only honest with the pointer outside)
read -r konx kony <<< "$(e2e_task_center "$tasks_view" org.kde.konsole.desktop)"
[[ -n "$konx" ]] || e2e_fail "could not locate the konsole task icon"

#! hover line: the icon centers, NOT the strip's outer rows - the last
#! few pixels at the screen edge are the edge margin (empty-area input),
#! and a hover there never reaches the task items
hovery=$kony
startx=$(( dx + dw / 3 ))
endx=$(( dx + dw * 2 / 3 ))

"$E2E_FAKEPOINTER" move "$startx" $(( hovery - 160 )); sleep 0.3
"$E2E_FAKEPOINTER" move "$startx" "$hovery"; sleep 0.4
x=$startx
while (( x < endx )); do "$E2E_FAKEPOINTER" move "$x" "$hovery"; x=$(( x + 16 )); done
#! finish over the konsole task so the preview delay elapses on it
"$E2E_FAKEPOINTER" move "$konx" "$hovery"
sleep 1.6   #! previewsDelay (throwaway default 650ms) + build time

previews="$(e2e_dumpwins | grep -cE '\|latte-dock\|\|[0-9.,-]+ [0-9]+x[0-9]+\|[^|]+\|layer=6' || true)"

#! leave the dock so zoom restores and the preview hides
"$E2E_FAKEPOINTER" move "$startx" $(( hovery - 400 )); sleep 1.2

if (( previews > 0 )); then
    echo "parabolic glide engaged; preview dialog mapped (layer=6)"
    exit 0
fi
e2e_fail "no preview dialog mapped after gliding the tasks region"
