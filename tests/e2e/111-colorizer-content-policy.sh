#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Latte Dock contributors
# SPDX-FileCopyrightText: 2026 Bree Spektor
# SPDX-License-Identifier: GPL-2.0-or-later
# e2e-mode: nested-only
#
# D28 (obsolete whole-applet colorfulness veto): palette propagation changes
# inherited Kirigami.Theme roles. It does not recolor fixed image, SVG, or
# Rectangle pixels, so a colorful fixed region must not veto palette response
# elsewhere in the same applet.
#
# Three deterministic applets isolate the policy:
# - responsive-only draws Kirigami.Theme.textColor;
# - fixed-only draws the literal #d62976;
# - mixed draws both controls side by side.
#
# Every fixture must report the palette as applied. Per-control screenshot
# crops then prove responsive pixels equal colorizerData.applyColor, fixed
# pixels retain their literal RGBA bytes, and the mixed applet satisfies both
# contracts in one rendered item. Sustained state sampling spans the retired
# probe's retry interval, so restoring the old asynchronous veto cannot pass
# during its initial unknown state.
set -uo pipefail
source "${E2E_REPO:?run through scripts/run-e2e.sh}/tests/e2e/lib.sh"

fixture="$E2E_REPO/tests/e2e/fixtures/d28"
theme="$E2E_REPO/tests/e2e/fixtures/d21/kdeglobals"
plugins=(
    org.kde.latte.d28-responsive
    org.kde.latte.d28-fixed
    org.kde.latte.d28-mixed
)

[[ -f "$fixture/D28.layout.latte" && -f "$theme" ]] \
    || e2e_fail "D28 layout or hermetic color scheme fixture is missing"
for plugin in "${plugins[@]}"; do
    [[ -f "$fixture/plasmoids/$plugin/metadata.json" \
        && -f "$fixture/plasmoids/$plugin/contents/ui/main.qml" ]] \
        || e2e_fail "D28 applet fixture is incomplete: $plugin"
done

# Install test-only packages into the nested process's private data home.
e2e_dock_stop || e2e_fail "could not stop the vehicle dock before staging D28"
export XDG_DATA_HOME="$E2E_RT/d28-data"
rm -rf "$XDG_DATA_HOME"
mkdir -p "$XDG_DATA_HOME/plasma/plasmoids"
cp -r "$fixture/plasmoids/." "$XDG_DATA_HOME/plasma/plasmoids/"

rm -f "$E2E_CONFIG_HOME"/latte/*.layout.latte
cp "$fixture/D28.layout.latte" "$E2E_CONFIG_HOME/latte/D28.layout.latte"
cp "$theme" "$E2E_CONFIG_HOME/kdeglobals"
python3 - "$E2E_CONFIG_HOME/lattedockrc" <<'PY'
import configparser
import sys

path = sys.argv[1]
config = configparser.RawConfigParser()
config.optionxform = str
config.read(path)
if not config.has_section("UniversalSettings"):
    config.add_section("UniversalSettings")
config.set("UniversalSettings", "singleModeLayoutName", "D28")
config.set("UniversalSettings", "memoryUsage", "0")
with open(path, "w") as output:
    config.write(output, space_around_delimiters=False)
PY

e2e_dock_start 90 || e2e_fail "dock never settled with the D28 fixture"

cid="$(e2e_json viewsData | python3 -c 'import json,sys
views=[view for view in json.load(sys.stdin) if view["edge"] in ("top", "bottom")]
print(views[0]["containmentId"] if views else "")')"
[[ -n "$cid" ]] || e2e_fail "no horizontal view came up from the D28 fixture"
echo "D28: horizontal view is containment $cid"

colorizer="$(e2e_json colorizerData u "$cid")"
apply_color="$(python3 - "$colorizer" <<'PY'
import json
import sys

colorizer = json.loads(sys.argv[1])
if colorizer.get("mustBeShown") is not True:
    sys.exit("D28 colorizer is not engaged")
color = colorizer.get("applyColor", "")
if len(color) != 7 or not color.startswith("#"):
    sys.exit("D28 colorizer has no resolved applyColor")
print(color)
PY
)" || e2e_fail "could not resolve the D28 panel palette"
echo "D28 palette foreground: $apply_color"

# The removed probe retried every two seconds. Requiring six consecutive
# one-second samples prevents its initial unknown state from producing a false
# pass if the veto is restored.
for sample in 1 2 3 4 5 6; do
    applets="$(e2e_json viewAppletsData u "$cid")"
    python3 - "$applets" "${plugins[@]}" <<'PY' \
        || e2e_fail "fixture applets did not remain colorizerActive=true reason=applied (sample $sample)"
import json
import sys

applets = {applet["plugin"]: applet for applet in json.loads(sys.argv[1])}
expected = sys.argv[2:]
missing = [plugin for plugin in expected if plugin not in applets]
bad = [
    (plugin, applets[plugin].get("colorizerActive"), applets[plugin].get("colorizerReason"))
    for plugin in expected
    if plugin in applets
    and not (
        applets[plugin].get("colorizerActive") is True
        and applets[plugin].get("colorizerReason") == "applied"
    )
]
if missing or bad:
    print("D28 state failure: missing=%s bad=%s" % (missing, bad), file=sys.stderr)
    sys.exit(1)
PY
    (( sample < 6 )) && sleep 1
done
echo "D28 STATE ok: responsive-only, fixed-only, and mixed fixtures stayed applied"

e2e_assert_geometry_agrees 2 \
    || e2e_fail "D28 control crops cannot trust view geometry"

shot="$E2E_ARTIFACTS/d28-content-policy.png"
e2e_screenshot "$shot" include-cursor b false \
    || e2e_fail "D28 screenshot failed"

# Convert each applet's view-local geometry into a screen crop. The controls
# are 28px squares; 12px center crops avoid antialiasing at their edges. The
# mixed controls are centered 18px to either side of the applet center.
views="$(e2e_json viewsData)"
crop_specs="$(python3 - "$cid" "$views" "$applets" <<'PY'
import json
import sys

containment_id = int(sys.argv[1])
views = json.loads(sys.argv[2])
applets = {applet["plugin"]: applet for applet in json.loads(sys.argv[3])}
view = next(view for view in views if view["containmentId"] == containment_id)
origin_x = view["absoluteGeometry"][0] - view["localGeometry"][0]
origin_y = view["absoluteGeometry"][1] - view["localGeometry"][1]

def center(plugin, offset=0):
    x, y, width, height = applets[plugin]["geometry"]
    return origin_x + x + width // 2 + offset, origin_y + y + height // 2

def emit(label, plugin, offset=0):
    center_x, center_y = center(plugin, offset)
    print("%s 12x12+%d+%d" % (label, center_x - 6, center_y - 6))

emit("responsive", "org.kde.latte.d28-responsive")
emit("fixed", "org.kde.latte.d28-fixed")
emit("mixed-responsive", "org.kde.latte.d28-mixed", -18)
emit("mixed-fixed", "org.kde.latte.d28-mixed", 18)
PY
)" || e2e_fail "could not resolve D28 per-control crop geometry"

declare -A crops
while read -r label rect; do
    crops["$label"]="$E2E_ARTIFACTS/d28-$label.png"
    magick "$shot" -crop "$rect" +repage "${crops[$label]}" \
        || e2e_fail "could not crop D28 $label control at $rect"
    echo "D28 crop $label: $rect"
done <<< "$crop_specs"

assert_solid_rgba() {
    local label="$1" expected="$2" image="${crops[$1]}" pixels
    pixels="$(magick "$image" -depth 8 txt:-)" \
        || e2e_fail "could not read D28 $label crop pixels"
    python3 - "$label" "$expected" "$pixels" <<'PY'
import re
import sys

label, expected_hex = sys.argv[1:3]
expected = tuple(bytes.fromhex(expected_hex.removeprefix("#"))) + (255,)
pixels = []
for line in sys.argv[3].splitlines():
    match = re.search(r"\((\d+),(\d+),(\d+)(?:,(\d+))?\)", line)
    if match:
        rgba = tuple(int(value) for value in match.groups(default="255"))
        pixels.append(rgba)
if len(pixels) != 144:
    sys.exit("D28 %s crop yielded %d pixels, expected 144" % (label, len(pixels)))
mismatches = [pixel for pixel in pixels if pixel != expected]
if mismatches:
    observed = sorted(set(mismatches))[:8]
    sys.exit(
        "D28 %s pixels differ from %s: %d/144 mismatches, observed %s"
        % (label, expected, len(mismatches), observed)
    )
print("D28 RENDER ok: %s is byte-exact %s" % (label, expected_hex))
PY
}

assert_solid_rgba responsive "$apply_color" \
    || e2e_fail "responsive-only content did not follow the panel palette"
assert_solid_rgba mixed-responsive "$apply_color" \
    || e2e_fail "responsive content in the mixed applet did not follow the panel palette"
assert_solid_rgba fixed "#d62976" \
    || e2e_fail "fixed-only content was recolored"
assert_solid_rgba mixed-fixed "#d62976" \
    || e2e_fail "fixed content in the mixed applet was recolored"

cmp <(magick "${crops[responsive]}" -depth 8 rgba:-) \
    <(magick "${crops[mixed-responsive]}" -depth 8 rgba:-) \
    || e2e_fail "mixed responsive pixels differ from the responsive-only control"
cmp <(magick "${crops[fixed]}" -depth 8 rgba:-) \
    <(magick "${crops[mixed-fixed]}" -depth 8 rgba:-) \
    || e2e_fail "mixed fixed pixels differ from the fixed-only control"

echo "PASS: D28 palette response and fixed-pixel stability (state + per-control render crops)"
