#!/usr/bin/env bash
# Source-scan rule test for the Qt6 QML contracts this port earned the hard
# way (latte-plasma6-defect-families, families 7 and 3).
#
# Rule 1: no autoPaddingEnabled anywhere in shipped QML except the literal
# `autoPaddingEnabled: false`. autoPadding recomputes the effect's padding
# and re-dirties it continuously, so every window carrying such an effect
# re-rendered empty frames forever - measured 18.2% idle CPU and ~19,500
# failing statx/s from per-frame theme lookups before e3376405 made
# ShadowedItem's padding static. Effects must carry a STATIC per-side
# paddingRect instead (per-side semantics: 6c7001ce).
#
# Rule 2: every when-gated Binding element in shipped QML must declare an
# explicit restoreMode. Qt6 changed the Binding default from RestoreNone to
# RestoreBindingOrValue, so a "Binding { when: }" meant to FREEZE its
# target's last value on deactivation instead RESETS it to the declared
# default - the regression that collapsed hovered applets to zero size. The
# tree ships 100+ when-gated freeze Bindings, all RestoreNone; the Qt
# semantics behind the rule are pinned by
# tests/contracts/tst_bindingrestorecontracts.qml. An explicit non-RestoreNone
# mode is allowed - the rule bans relying on the silent default, not making a
# deliberate choice.
#
# This is a plain source scan, not a staged install: the rules must hold for
# every shipped QML file whether or not a build exists.
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"

shipped=(
    "$repo/containment"
    "$repo/plasmoid"
    "$repo/shell"
    "$repo/declarativeimports"
    "$repo/indicators"
)

fail=0

# --- Rule 1: autoPaddingEnabled ---------------------------------------------
# Property assignments only (identifier followed by a colon); prose mentions
# of the property name in comments are fine.
violations="$(grep -rn --include='*.qml' -E 'autoPaddingEnabled[[:space:]]*:' "${shipped[@]}" \
    | grep -vE 'autoPaddingEnabled[[:space:]]*:[[:space:]]*false([[:space:];/]|$)' || true)"

if [[ -n "$violations" ]]; then
    echo "FAIL: autoPaddingEnabled must only ever be assigned the literal 'false' in shipped QML:" >&2
    echo "$violations" >&2
    fail=1
fi

# --- Rule 2: when-gated Binding must declare restoreMode ---------------------
# Brace-matching over Binding elements (`Binding {` and `Binding on prop {`),
# so restoreMode references elsewhere in the file cannot satisfy the rule for
# a different Binding.
binding_violations="$(find "${shipped[@]}" -name '*.qml' -print0 | xargs -0 awk '
{
    lines[FNR] = $0
}
ENDFILE {
    src = ""
    for (i = 1; i <= FNR; i++) src = src lines[i] "\n"
    delete lines
    pos = 1
    while (match(substr(src, pos), /Binding([ \t\n]+on[ \t]+[A-Za-z_.]+)?[ \t\n]*\{/)) {
        start = pos + RSTART - 1
        brace = start + RLENGTH - 1
        depth = 0
        j = brace
        n = length(src)
        while (j <= n) {
            c = substr(src, j, 1)
            if (c == "{") depth++
            else if (c == "}") { depth--; if (depth == 0) { j++; break } }
            j++
        }
        block = substr(src, brace, j - brace)
        if (block ~ /when[ \t]*:/ && block !~ /restoreMode[ \t]*:/) {
            pre = substr(src, 1, start)
            print FILENAME ":" gsub(/\n/, "", pre) + 1
        }
        pos = j
    }
}
' || true)"

if [[ -n "$binding_violations" ]]; then
    echo "FAIL: when-gated Binding elements without an explicit restoreMode (Qt6 default" >&2
    echo "RestoreBindingOrValue resets the frozen value; declare restoreMode, usually" >&2
    echo "Binding.RestoreNone - see tests/contracts/tst_bindingrestorecontracts.qml):" >&2
    echo "$binding_violations" >&2
    fail=1
fi

if [[ "$fail" != 0 ]]; then
    exit 1
fi

echo "qml-effect-rules: OK (autoPaddingEnabled only ever disabled; every when-gated Binding declares restoreMode)"
