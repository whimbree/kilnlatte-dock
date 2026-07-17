#!/usr/bin/env bash
# E2E: the dock renders where it says it does. Every locatable horizontal
# view's layer-shell surface must sit at the origin viewsData reports - a
# state-vs-render AGREEMENT check, the one bug class the rest of the suite's
# D-Bus assertions are blind to by construction (viewsData stays
# self-consistent even when the compositor draws the surface elsewhere).
#
# This recipe carries "# e2e-expect: fail" because it currently reproduces the
# filed Phase 8 bottom-dock surface drift (the surface renders 20-74px left of
# its reported geometry and re-anchors on clock-minute ticks). The driver
# treats that expected failure as XFAIL and does not count it against the
# suite. When Phase 8 is fixed the assertion PASSES, the driver reports XPASS
# and goes red on purpose - that is the signal to delete the two marker lines
# below, at which point this becomes a permanent standing guard against any
# future divergence.
# e2e-mode: nested-only
# e2e-expect: fail
set -u

repo="${E2E_REPO:?run through scripts/run-e2e.sh}"
source "$repo/tests/e2e/lib.sh"

e2e_wait_settled 45 || e2e_fail "vehicle dock never settled"

# 2px tolerance absorbs sub-pixel rounding; the Phase 8 drift is an order of
# magnitude larger, so this is not a clamp hiding the bug - it is the width of
# honest rounding noise and no wider.
e2e_assert_geometry_agrees 2 || e2e_fail "a view renders off its reported geometry (state/render divergence)"

echo "PASS: geometry-agreement"
exit 0
