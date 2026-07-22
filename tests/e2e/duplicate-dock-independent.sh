#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Bree Spektor
# SPDX-FileCopyrightText: 2026 Latte Dock contributors
# SPDX-License-Identifier: GPL-2.0-or-later
#
# D77 (dock duplication retains clone lineage and edit ownership) dual-output
# acceptance. Duplicate Dock must create exactly one independent snapshot from
# either member of an existing linked replica relationship. The copied dock
# receives fresh containment and applet identities, no clone graph entry, and
# remains independent after persistence reload.
# e2e-mode: nested-only
set -uo pipefail
source "${E2E_REPO:?run through scripts/run-multi-output-e2e.sh}/tests/e2e/lib.sh"

[[ "${E2E_OUTPUT_COUNT:-1}" -eq 2 ]] \
    || e2e_fail "duplicate-dock-independent needs the dual-output vehicle"

view_ids() {
    e2e_json viewsData | python3 -c '
import json, sys
print(" ".join(str(v["containmentId"]) for v in json.load(sys.stdin)))
'
}

applet_ids() {
    local view="$1"
    e2e_json viewAppletsData u "$view" | python3 -c '
import json, sys
print(" ".join(str(a["id"]) for a in json.load(sys.stdin)))
'
}

wait_for_linked_pair() {
    local i state result
    for ((i = 0; i < 80; ++i)); do
        state="$(e2e_json viewsData)"
        result="$(python3 -c '
import json, sys
views = json.load(sys.stdin)
originals = [v for v in views if not v["isCloned"]]
clones = [v for v in views if v["isCloned"]]
if len(originals) == 1 and len(clones) == 1 and clones[0]["isClonedFrom"] == originals[0]["containmentId"]:
    print(originals[0]["containmentId"], clones[0]["containmentId"])
' <<<"$state")"
        [[ -n "$result" ]] && { echo "$result"; return 0; }
        sleep 0.25
    done
    return 1
}

duplicate_once() {
    local source="$1" label="$2" before="$3" i current candidate final
    e2e_call duplicateView u "$source" >/dev/null \
        || e2e_fail "$label duplicateView call failed for containment $source"

    candidate=""
    for ((i = 0; i < 100; ++i)); do
        current="$(e2e_json viewsData)"
        candidate="$(python3 -c '
import json, sys
before = {v["containmentId"] for v in json.loads(sys.stdin.readline())}
after = json.loads(sys.stdin.readline())
created = [v for v in after if v["containmentId"] not in before]
if len(created) == 1 and not created[0]["isCloned"] and created[0]["isClonedFrom"] == -1:
    print(created[0]["containmentId"])
' <<<"$before
$current")"
        [[ -n "$candidate" ]] && break
        sleep 0.2
    done
    [[ -n "$candidate" ]] \
        || e2e_fail "$label did not create one independent containment"

    # Allow the old copied AllScreensGroup policy enough time to spawn its
    # second-output clone. A transient one-view state must not pass this check.
    sleep 3
    final="$(e2e_json viewsData)"
    { echo "$before"; echo "$final"; } | python3 -c '
import json, sys
before = {v["containmentId"] for v in json.loads(sys.stdin.readline())}
after = json.loads(sys.stdin.readline())
created = [v for v in after if v["containmentId"] not in before]
if len(created) != 1:
    sys.exit("expected exactly one new view, got %d: %s" % (len(created), created))
v = created[0]
if v["isCloned"] or v["isClonedFrom"] != -1:
    sys.exit("new view retained a clone graph entry: %s" % v)
' || e2e_fail "$label created a linked ensemble instead of one independent dock"

    echo "$candidate"
}

initial="$(e2e_json viewsData)"
source_id="$(python3 -c '
import json, sys
views = [v for v in json.load(sys.stdin) if not v["isCloned"]]
if len(views) != 1:
    sys.exit("expected one initial original, saw %d" % len(views))
print(views[0]["containmentId"])
' <<<"$initial")"

# Turn the seed dock into an existing linked relationship without changing its
# containment identity. Existing linked layout migration must preserve this
# pair; only newly duplicated docks are normalized.
e2e_dock_stop || e2e_fail "could not stop the seed dock before linking outputs"
kwriteconfig6 --file "$E2E_LAYOUT" --group Containments --group "$source_id" --key screensGroup 1
e2e_dock_start || e2e_fail "linked seed dock did not restart"
read -r original_id replica_id <<< "$(wait_for_linked_pair)" \
    || e2e_fail "AllScreensGroup did not create one original and one linked replica"

baseline="$(e2e_json viewsData)"
baseline_applets="$(for id in $(view_ids); do applet_ids "$id"; done | tr '\n' ' ')"

from_original="$(duplicate_once "$original_id" "original-source" "$baseline")"
after_original="$(e2e_json viewsData)"
from_replica="$(duplicate_once "$replica_id" "replica-source" "$after_original")"

[[ "$from_original" != "$from_replica" ]] \
    || e2e_fail "both duplicate calls returned containment $from_original"

duplicate_applets="$(applet_ids "$from_original") $(applet_ids "$from_replica")"
{ echo "$baseline_applets"; echo "$duplicate_applets"; } | python3 -c '
import sys
baseline = {int(v) for v in sys.stdin.readline().split()}
created = [int(v) for v in sys.stdin.readline().split()]
if len(created) != len(set(created)):
    sys.exit("duplicate applet ids overlap each other: %s" % created)
overlap = baseline.intersection(created)
if overlap:
    sys.exit("duplicate applet ids overlap the linked source: %s" % sorted(overlap))
' || e2e_fail "duplicate applet identities were not fresh"

# Drive a real original-to-replica property synchronization after both
# duplicates exist. ClonedView connects the original VisibilityManager's mode
# signal to every relationship member. Neither independent snapshot may receive
# that change.
before_modes="$(e2e_json viewsData)"
read -r old_mode new_mode <<< "$(python3 -c '
import json, sys
views = json.load(sys.stdin)
source = next(v for v in views if v["containmentId"] == int(sys.argv[1]))
old = source["visibilityMode"]
new = "dodgeActive" if old == "alwaysVisible" else "alwaysVisible"
print(old, new)
' "$original_id" <<<"$before_modes")"

e2e_call setViewVisibilityMode us "$original_id" "$new_mode" >/dev/null \
    || e2e_fail "could not drive source relationship visibility synchronization"

sync_observed=false
for _ in $(seq 1 80); do
    current_modes="$(e2e_json viewsData)"
    if { echo "$current_modes"; } | python3 -c '
import json, sys
views = {v["containmentId"]: v for v in json.load(sys.stdin)}
original, replica = (int(v) for v in sys.argv[1:3])
want = sys.argv[3]
sys.exit(0 if views[original]["visibilityMode"] == want and views[replica]["visibilityMode"] == want else 1)
' "$original_id" "$replica_id" "$new_mode"; then
        sync_observed=true
        break
    fi
    sleep 0.25
done
[[ "$sync_observed" == true ]] \
    || e2e_fail "existing linked relationship did not synchronize visibility mode"
for id in "$from_original" "$from_replica"; do
    [[ "$(e2e_view_field "$id" 'v["visibilityMode"]')" == "$old_mode" ]] \
        || e2e_fail "duplicate $id retained source visibility synchronization"
done

# A clean stop flushes the lazy layout file. Both duplicates must persist as
# single-screen originals. The pre-existing linked pair must remain linked.
e2e_dock_stop || e2e_fail "could not stop the dock for persistence checks"
for id in "$from_original" "$from_replica"; do
    [[ "$(kreadconfig6 --file "$E2E_LAYOUT" --group Containments --group "$id" --key isClonedFrom --default -999)" == -1 ]] \
        || e2e_fail "duplicate $id persisted a clone source"
    [[ "$(kreadconfig6 --file "$E2E_LAYOUT" --group Containments --group "$id" --key screensGroup --default -999)" == 0 ]] \
        || e2e_fail "duplicate $id persisted a multi-output replica policy"
done
[[ "$(kreadconfig6 --file "$E2E_LAYOUT" --group Containments --group "$original_id" --key screensGroup --default -999)" == 1 ]] \
    || e2e_fail "existing linked original $original_id lost AllScreensGroup during duplication"
[[ "$(kreadconfig6 --file "$E2E_LAYOUT" --group Containments --group "$replica_id" --key isClonedFrom --default -999)" == "$original_id" ]] \
    || e2e_fail "existing replica $replica_id lost source $original_id during duplication"

e2e_dock_start || e2e_fail "dock did not restart for duplicate persistence proof"
reloaded="$(e2e_json viewsData)"
python3 -c '
import json, sys
views = json.load(sys.stdin)
expected = {int(v) for v in sys.argv[1:]}
duplicates = [int(v) for v in sys.argv[-2:]]
actual = {v["containmentId"] for v in views}
if actual != expected:
    sys.exit("reload changed view membership: expected %s, got %s" % (sorted(expected), sorted(actual)))
by_id = {v["containmentId"]: v for v in views}
for duplicate in duplicates:
    if by_id[duplicate]["isCloned"] or by_id[duplicate]["isClonedFrom"] != -1:
        sys.exit("duplicate %d rejoined a clone graph after reload" % duplicate)
' "$original_id" "$replica_id" "$from_original" "$from_replica" <<<"$reloaded" \
    || e2e_fail "independent duplicates did not survive reload"

echo "duplicate dock: original $original_id and replica $replica_id each produced one fresh independent dock ($from_original, $from_replica); source sync bypassed both and reload preserved all identities"
