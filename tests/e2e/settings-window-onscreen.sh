#!/usr/bin/env bash
# E2E: the view settings window maps FULLY on-screen on a cold session
# (the 1b932ed9 regression: upstream's self-origin exclusion made the
# chrome map 99px above the screen top on cold starts). Consumes the
# EX-08 ScreenGeometryCalculator path end to end. Triggered through
# kglobalaccel ("show view settings") - inside the vehicle KWin itself
# provides org.kde.kglobalaccel on the private bus, so the shortcut
# registration path is exercised in both modes.
set -uo pipefail
source "${E2E_REPO:?run through scripts/run-e2e.sh}/tests/e2e/lib.sh"

invoke_settings() {
    busctl --user call org.kde.kglobalaccel /component/lattedock \
        org.kde.kglobalaccel.Component invokeShortcut s "show view settings" >/dev/null
}

settings_window_mapped() {
    e2e_dumpwins | awk -F'|' '
        $2 ~ /latte-dock/ {
            split($4, g, " "); split(g[2], size, "x");
            if (size[2] > 400 && size[1] > 300 && size[1] < 2000) found=1
        }
        END { exit found ? 0 : 1 }'
}

invoke_settings
sleep 3
#! first invoke can race kglobalaccel registration
if ! settings_window_mapped; then
    invoke_settings
    sleep 2.5
fi

#! screen bounds come from the dock's own report (viewsData), not from a
#! plasmashell window - the vehicle has no plasmashell
screen="$(e2e_json viewsData | python3 -c '
import json, sys
views = json.load(sys.stdin)
if not views:
    sys.exit("no views")
print(*views[0]["screenGeometry"])
')"
read -r sx sy sw sh <<< "$screen"

result="$(e2e_dumpwins | awk -F'|' -v sx="$sx" -v sy="$sy" -v sw="$sw" -v sh="$sh" '
    $2 ~ /latte-dock/ {
        split($4, g, " "); split(g[1], pos, ","); split(g[2], size, "x");
        x = pos[1]; y = pos[2]; w = size[1]; h = size[2];
        if (h > 400 && w > 300 && w < 2000) { cx=x; cy=y; cw=w; ch=h; found=1 }
    }
    END {
        if (!found) { print "NOCONFIG"; exit }
        if (cx >= sx && cy >= sy && cx+cw <= sx+sw && cy+ch <= sy+sh) print "ONSCREEN";
        else printf "OFFSCREEN config=%s,%s %sx%s screen=%s,%s %sx%s\n", cx, cy, cw, ch, sx, sy, sw, sh;
    }')"

#! close the settings again: focus-loss click at screen center first (the
#! Qt5-faithful path), then the deterministic D-Bus close for every view -
#! in the vehicle there is no other focusable window, so the click alone
#! cannot be relied on to dismiss the chrome
"$E2E_FAKEPOINTER" click $(( sx + sw / 2 )) $(( sy + sh / 2 )) >/dev/null 2>&1 || true
sleep 1
for vid in $(e2e_json viewsData | python3 -c '
import json, sys
for v in json.load(sys.stdin):
    print(v["containmentId"])
'); do
    e2e_call setViewEditMode ub "$vid" false >/dev/null 2>&1 || true
done
sleep 1

case "$result" in
    ONSCREEN) echo "settings window fully on-screen"; exit 0;;
    NOCONFIG) e2e_fail "no settings window mapped after two invokes";;
    *)        e2e_fail "$result";;
esac
