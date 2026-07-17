#!/usr/bin/env bash
# E2E: dbus duplicateView produces a collision-free containment whose
# appletOrder references exactly its own new applet ids (the EX-07
# StorageIdRemapper path end to end), then removes the duplicate and
# waits out the libplasma undo window before finishing.
set -uo pipefail
source "${E2E_REPO:?run through scripts/run-e2e.sh}/tests/e2e/lib.sh"
layout="${E2E_LAYOUT:?run through scripts/run-e2e.sh}"

[[ -f "$layout" ]] || e2e_fail "throwaway layout not found at $layout"

before_ids="$(grep -E '^\[Containments\]\[[0-9]+\]$' "$layout" | grep -oE '[0-9]+' | sort -n | uniq)"
src_id="$(echo "$before_ids" | head -1)"

e2e_call duplicateView u "$src_id" >/dev/null

#! the new view appears on the bus first; the layout file follows on the
#! next config flush (on-disk config is a LAZY witness - the CaptSilver
#! adoption's finding - so poll it instead of trusting one sleep)
new_id=""
for _ in $(seq 1 30); do
    sleep 2
    after_ids="$(grep -E '^\[Containments\]\[[0-9]+\]$' "$layout" | grep -oE '[0-9]+' | sort -n | uniq)"
    new_id="$(comm -13 <(echo "$before_ids") <(echo "$after_ids") | head -1)"
    [[ -n "$new_id" ]] && break
done

if [[ -z "$new_id" ]]; then
    live="$(e2e_json viewsData | grep -o '"containmentId"' | wc -l)"
    e2e_fail "no new containment reached the layout file after 60s (viewsData reports $live views)"
fi

#! collision-free by construction of comm; check the applet references
order="$(awk -v id="$new_id" '$0=="[Containments]["id"][General]"{f=1;next} /^\[/{f=0} f&&/^appletOrder=/{sub(/^appletOrder=/,""); print}' "$layout")"
applets="$(grep -oE "^\[Containments\]\[$new_id\]\[Applets\]\[[0-9]+\]$" "$layout" | grep -oE '[0-9]+\]$' | tr -d ']' | sort -n)"

ok=1
if [[ -n "$order" ]]; then
    for token in ${order//;/ }; do
        echo "$applets" | grep -qx "$token" || { echo "FAIL: appletOrder token $token has no applet group"; ok=0; }
    done
fi

#! cleanup: remove the duplicate and wait out the undo window
e2e_call removeView u "$new_id" >/dev/null
for i in $(seq 1 24); do
    grep -q "^\[Containments\]\[$new_id\]$" "$layout" || break
    sleep 5
done
grep -q "^\[Containments\]\[$new_id\]$" "$layout" && e2e_fail "duplicate $new_id still in layout after undo window"

[[ "$ok" == 1 ]] && echo "duplicate $src_id -> $new_id: ids collision-free, appletOrder consistent, cleaned up"
[[ "$ok" == 1 ]]
