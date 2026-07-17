#!/usr/bin/env bash
# E2E: keyboard focus mode lifecycle over D-Bus in the nested vehicle -
# enter/exit readback (viewsData keyboardNavigation), unknown-id refusal,
# and the bulletproof focus-loss exit: with the mode on, a client window
# mapping in the compositor takes the keyboard focus and the mode must
# fall back to off ON ITS OWN (a dock stuck focusable breaks every
# fullscreen application - that is the defect class this pins).
#
# Unlike the sibling e2e scripts this one is self-contained: it starts
# its own staged dock against a throwaway config copy, so it must run
# inside the nested vehicle with a PRIVATE bus (the dock exits instantly
# on the KDBusService unique name otherwise - the documented trap):
#
#   nix develop -c tests/sceneprobe/run_in_kwin.sh dbus-run-session -- \
#       tests/e2e/keyboard-navigation-mode.sh
#
# The focus-taker is a minimal QML window, not konsole: konsole's cold
# start inside the nested session exceeded every reasonable wait and the
# focus-loss leg timed out on it (caught 2026-07-17 while landing the
# mode; the qml window maps in about a second).
set -u

repo="$(cd "$(dirname "$0")/../.." && pwd)"
scratch="$(mktemp -d /tmp/kbnav-e2e.XXXXXX)"
log="$scratch/dock.log"
cfg="$scratch/config"
mkdir -p "$cfg"
if [ -d "$repo/build/_runconfig" ]; then
    cp -r "$repo/build/_runconfig/." "$cfg/"
fi

cat > "$scratch/focus-taker.qml" <<'EOF'
import QtQuick
Window { visible: true; width: 300; height: 200; title: "kbnav-focus-taker" }
EOF

call() { busctl --user call org.kde.lattedock /Latte org.kde.LatteDock "$@"; }
viewsjson() { call viewsData | sed 's/^s "//; s/"$//; s/\\"/"/g'; }

env LATTE_CONFIG_HOME="$cfg" "$repo/scripts/run-staged.sh" -d > "$log" 2>&1 &
DOCK=$!
TAKER=""

cleanup() {
    [ -n "$TAKER" ] && kill "$TAKER" 2>/dev/null
    kill "$DOCK" 2>/dev/null
    rm -rf "$scratch" 2>/dev/null
}
trap cleanup EXIT INT TERM

fail() { echo "FAIL: $1"; exit 1; }
pass() { echo "ok: $1"; }

state=""
for _ in $(seq 1 45); do
    state=$(call lifecycleState 2>/dev/null | awk '{print $2}')
    [ "$state" = '"running"' ] && break
    kill -0 "$DOCK" 2>/dev/null || fail "dock died during startup (log kept out of tree: $log)"
    sleep 1
done
[ "$state" = '"running"' ] || fail "dock never reached running"
pass "lifecycleState running"

#! "running" is corona-level; the views themselves can appear and settle
#! moments later - poll for a real record, then for inStartup to clear
cid=""
for _ in $(seq 1 30); do
    cid=$(viewsjson | jq -r '.[0].containmentId // empty' 2>/dev/null)
    [ -n "$cid" ] && break
    sleep 1
done
{ [ -n "$cid" ] && [ "$cid" != "null" ]; } || fail "no containment id in viewsData"

for _ in $(seq 1 20); do viewsjson | grep -q '"inStartup":true' || break; sleep 1; done
pass "containment id $cid"

kbnav() { viewsjson | jq -r ".[] | select(.containmentId == $cid) | .keyboardNavigation"; }

[ "$(kbnav)" = "false" ] || fail "baseline keyboardNavigation is not false"
pass "baseline false (mode off is the default)"

#! unknown id is refused loudly, dock stays alive, real view untouched
call setViewKeyboardNavigation ub 999999 true >/dev/null 2>&1
sleep 1
[ "$(call lifecycleState | awk '{print $2}')" = '"running"' ] || fail "dock died on unknown-id refusal"
[ "$(kbnav)" = "false" ] || fail "unknown-id call changed the real view's state"
pass "unknown containment id refused, dock alive"

call setViewKeyboardNavigation ub "$cid" true >/dev/null
got=""; for _ in $(seq 1 10); do got=$(kbnav); [ "$got" = "true" ] && break; sleep 0.5; done
[ "$got" = "true" ] || fail "enter did not read back keyboardNavigation true"
pass "enter over D-Bus: keyboardNavigation true"

call setViewKeyboardNavigation ub "$cid" false >/dev/null
got=""; for _ in $(seq 1 10); do got=$(kbnav); [ "$got" = "false" ] && break; sleep 0.5; done
[ "$got" = "false" ] || fail "exit did not read back keyboardNavigation false"
pass "exit over D-Bus: keyboardNavigation false"

#! the focus-loss exit
call setViewKeyboardNavigation ub "$cid" true >/dev/null
for _ in $(seq 1 10); do [ "$(kbnav)" = "true" ] && break; sleep 0.5; done
[ "$(kbnav)" = "true" ] || fail "re-enter before the focus-loss leg failed"

qml "$scratch/focus-taker.qml" > /dev/null 2>&1 &
TAKER=$!
got=""
for _ in $(seq 1 60); do
    got=$(kbnav); [ "$got" = "false" ] && break; sleep 0.5
done
kill "$TAKER" 2>/dev/null; TAKER=""
[ "$got" = "false" ] || fail "focus loss did not exit keyboard navigation (dock stuck focusable)"
pass "focus loss exits the mode on its own"

#! exit is idempotent
call setViewKeyboardNavigation ub "$cid" false >/dev/null
sleep 1
[ "$(call lifecycleState | awk '{print $2}')" = '"running"' ] || fail "dock died on idempotent exit"
pass "idempotent exit, dock alive"

echo "PASS: keyboard-navigation-mode"
exit 0
