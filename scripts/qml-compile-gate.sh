#!/usr/bin/env bash
# Headless compile-check for every QML file in the shell, containment and
# indicator packages (porting plan Phase 5). Compiles each file in a real QML
# engine via Qt.createComponent, so it catches removed-type and
# removed-property errors in lazy, interaction-only components (widget
# explorer, config pages) that would otherwise need a click in a live session
# to surface. It compiles, it does not instantiate: type resolution and
# property-assignment existence are checked, runtime binding evaluation is
# not.
#
# Skipped file classes, reported in the output:
#   * files importing org.kde.latte.private.app - that module is registered
#     inside the latte-dock binary (lattecorona.cpp), it never exists for a
#     standalone engine; these all load during dock startup anyway
#   * the tasks plasmoid - still unported Plasma 5 QML until Phase 6
#
# Runs inside the flake devShell (ctest invokes it there via build-check.sh).
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"

source "$repo/scripts/lib-qml-env.sh"
qml_env_setup "$repo"
qml_env_stage

mapfile -t all < <(find \
    "$stage/share/plasma/shells/org.kde.latte.shell" \
    "$stage/share/plasma/plasmoids/org.kde.latte.containment" \
    "$stage/share/latte/indicators" \
    -name '*.qml' 2>/dev/null | sort)

if [[ "${#all[@]}" -eq 0 ]]; then echo "no staged QML found under $stage"; exit 2; fi

files=(); skipped_app=0; skipped_ws=0
for f in "${all[@]}"; do
    if grep -q 'org.kde.latte.private.app' "$f"; then skipped_app=$((skipped_app+1)); continue; fi
    #! org.kde.plasma.private.shell only exists in plasma-workspace, whose
    #! nixpkgs build currently rides a foreign Qt pin (see import filtering
    #! above); these files can only load in the live session
    if grep -q 'org.kde.plasma.private.shell' "$f"; then skipped_ws=$((skipped_ws+1)); continue; fi
    files+=("$f")
done
echo "skipped $skipped_app app-module-dependent + $skipped_ws plasma-workspace-module files (they load with the running dock)"

gen="$stage/_compile_gate.qml"
{
    echo 'import QtQuick'
    echo 'import QtTest'
    echo 'TestCase {'
    echo '    name: "QmlCompileGate"'
    echo '    property var files: ['
    for f in "${files[@]}"; do echo "        \"file://$f\","; done
    echo '    ]'
    echo '    function test_compileAll() {'
    echo '        var failed = [];'
    echo '        for (var i = 0; i < files.length; i++) {'
    echo '            var c = Qt.createComponent(files[i]);'
    echo '            if (c.status === Component.Error) {'
    echo '                console.warn("FAIL " + files[i] + "\n      " + c.errorString().trim());'
    echo '                failed.push(files[i]);'
    echo '            }'
    echo '            if (c) c.destroy();'
    echo '        }'
    echo '        console.warn("=== " + failed.length + " of " + files.length + " package QML files failed to compile ===");'
    echo '        verify(failed.length === 0, failed.length + " QML files failed to compile");'
    echo '    }'
    echo '}'
} > "$gen"

echo "compiling ${#files[@]} QML files (offscreen)..."
QT_QPA_PLATFORM=offscreen qmltestrunner "${imports[@]}" -input "$gen"
