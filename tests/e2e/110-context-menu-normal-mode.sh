#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Latte Dock contributors
# SPDX-FileCopyrightText: 2026 Bree Spektor
# SPDX-License-Identifier: GPL-2.0-or-later
# e2e-mode: nested-only
#
# D20 guard: the dock right-click context menu must expose the FULL
# always-shown action set in NORMAL (non-edit) mode.
#
# menu.cpp:288 shows each normal-mode action iff
# m_actionsAlwaysShown.contains(action) || configuring, where
# m_actionsAlwaysShown is contextMenuData index 3 (the ;;-joined always-shown
# list from UniversalSettings::contextMenuActionsAlwaysShown). So when that
# list is empty, normal mode (configuring==false) hides every Latte action
# except the section header and Edit Dock - the D20 collapse. EDIT mode masks
# the fault entirely (|| configuring shows everything), which is why the
# port's edit-mode-only menu verification (PORTING_PLAN menu check) never
# caught it. This is the missing normal-mode assertion.
#
# The assertion is on the DATA menu.cpp gates on (contextMenuData index 3),
# not on rendered menu pixels: index 3 is precisely the input to the
# normal-mode visibility decision, and it is pull-queryable.
set -uo pipefail
source "${E2E_REPO:?run through scripts/run-e2e.sh}/tests/e2e/lib.sh"

# The always-shown ids a default/rich config exposes
# (app/data/contextmenudata.h ACTIONSALWAYSVISIBLE). Sorted for
# order-independent comparison; the D-Bus feed carries config order.
EXPECTED_ALWAYS="_add_latte_widgets _add_view _layouts _preferences _quit_latte _separator1"

# _feed_index3 <cid>: the raw ;;-joined always-shown feed (contextMenuData
# index 3) for a containment, exactly the string menu.cpp splits and gates on.
_feed_index3() {
    busctl --user --json=short call org.kde.lattedock /Latte org.kde.LatteDock \
        contextMenuData u "$1" | python3 -c '
import json, sys
d = json.load(sys.stdin)["data"][0]
sys.stdout.write(d[3] if len(d) > 3 else "")
'
}

# _sorted_ids <feed>: the feed as a sorted, space-joined id set (empty feed ->
# empty output), so the guard compares sets, not serialisation order.
_sorted_ids() {
    printf '%s' "$1" | python3 -c '
import sys
print(" ".join(sorted(p for p in sys.stdin.read().split(";;") if p)))
'
}

# assert_full_always_set <feed> <label>: the exact D20 guard. Passes iff the
# feed's id set is the full expected always-shown set; fails loud otherwise.
# This is the SINGLE assertion driven live below AND exercised by the negative
# control, so a proven-rejecting negative control proves the live pass is real.
assert_full_always_set() {
    local feed="$1" label="$2" got expected
    got="$(_sorted_ids "$feed")"
    expected="$(_sorted_ids "${EXPECTED_ALWAYS// /;;}")"
    if [[ "$got" != "$expected" ]]; then
        echo "assert_full_always_set: $label always-shown set is [$got], expected [$expected]" >&2
        return 1
    fi
    return 0
}

e2e_wait_running 30 || e2e_fail "dock not running"
e2e_wait_settled 30 || e2e_fail "views did not settle"

# --- the guard: every view, in normal mode, exposes the full always-shown set
checked=0
for cid in $(e2e_json viewsData | python3 -c 'import json,sys; print("\n".join(str(v["containmentId"]) for v in json.load(sys.stdin)))'); do
    #! normal mode is the whole point: edit mode would mask an emptied list
    editmode="$(e2e_view_field "$cid" 'v["editMode"]')"
    [[ "$editmode" == "False" ]] \
        || e2e_fail "view $cid reports editMode=$editmode; the normal-mode guard needs configuring==false"

    assert_full_always_set "$(_feed_index3 "$cid")" "view $cid (normal mode)" \
        || e2e_fail "view $cid right-click menu is collapsed in normal mode (D20): the always-shown feed does not carry the full action set"
    checked=$((checked + 1))
done
(( checked > 0 )) || e2e_fail "no views were available to check"
echo "normal-mode context menu: full always-shown set present on $checked view(s)"

# --- negative control: the SAME assertion must REJECT the D20 states, or the
# guard above is vacuous. An emptied key (the D20 collapse) and any partial
# feed must both fail. Proven live too: seeding contextMenuActionsAlwaysShown=
# and restarting drives contextMenuData index 3 to '' (recorded in the D20
# entry); here the assertion is shown to reject that exact feed shape.
for bad in "" "_layouts" "_layouts;;_preferences;;_quit_latte"; do
    if assert_full_always_set "$bad" "negative-control [$bad]" 2>/dev/null; then
        e2e_fail "negative control: the guard ACCEPTED a collapsed/partial feed [$bad] - it would not catch D20"
    fi
done
echo "negative control: the guard rejects the emptied (D20) and partial always-shown feeds"
