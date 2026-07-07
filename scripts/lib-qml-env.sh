# Shared QML environment assembly for the headless QML checks (sourced by
# qml-compile-gate.sh and qml-interaction-tests.sh). Assumes bash with
# nounset; sets the `imports` array and the `stage` directory.
#
# The user profile's QML2_IMPORT_PATH must not leak in: it carries Qt 5 and
# differently-pinned Qt 6 builds whose plugins fail to load in this runtime
# (private-API symbol versioning). The same applies to the engine's ambient
# defaults on this host, so every needed module is passed explicitly with
# -import; a later -import outranks earlier ones and the ambient defaults.

qml_env_setup() {
    local repo="$1"
    build="${BUILD:-$repo/build}"
    stage="${STAGE:-$build/_qmlstage}"

    unset QML2_IMPORT_PATH QML_IMPORT_PATH

    # NIXPKGS_QT6_QML_IMPORT_PATH covers the KDE framework modules;
    # NIXPKGS_QML_SEARCH_PATHS the pinned Qt modules themselves. Entries from
    # a foreign Qt closure (the plasma-workspace build dependency currently
    # rides a different Qt pin) cannot dlopen here and are filtered out.
    local qtver p
    qtver="$(qtpaths --query QT_VERSION)"
    imports=()
    IFS=':' read -ra _qmldirs <<< "${NIXPKGS_QT6_QML_IMPORT_PATH:-}:${NIXPKGS_QML_SEARCH_PATHS:-}"
    for p in "${_qmldirs[@]}"; do
        [[ -d "$p" ]] || continue
        if [[ "$p" =~ -qt[a-z0-9]+-([0-9]+\.[0-9]+\.[0-9]+)(/|$) ]] && [[ "${BASH_REMATCH[1]}" != "$qtver" ]]; then
            continue
        fi
        imports+=(-import "$p")
    done

    # pin org.kde.plasma.* to the exact libplasma the binary links, in case a
    # second copy exists in the closure
    local linked_plasma
    linked_plasma="$(ldd "$build/bin/latte-dock" | perl -ne 'print $1 if m{=> (\S+)/lib/libPlasma\.so}')"
    [[ -n "$linked_plasma" && -d "$linked_plasma/lib/qt-6/qml" ]] && imports+=(-import "$linked_plasma/lib/qt-6/qml")

    # the staged Latte modules win over everything
    imports+=(-import "$stage/lib/qml")
}

qml_env_stage() {
    echo "staging $build -> $stage ..."
    rm -rf "$stage"

    # cmake --install unconditionally rewrites build/install_manifest.txt,
    # which ECM's appstreamtest reads; leaving the staged manifest behind
    # changes what that test validates. Preserve whatever state it had.
    local manifest="$build/install_manifest.txt" had_manifest=""
    [[ -f "$manifest" ]] && { had_manifest=1; cp "$manifest" "$manifest.pre-stage"; }

    cmake --install "$build" --prefix "$stage" >"$stage.log" 2>&1 || {
        echo "STAGE FAILED:"; tail -15 "$stage.log"; return 2;
    }

    if [[ -n "$had_manifest" ]]; then
        mv "$manifest.pre-stage" "$manifest"
    else
        rm -f "$manifest"
    fi
}
