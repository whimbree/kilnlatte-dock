# P3b transplant wave - running ledger (2026-07-17)

Worktree: /tmp/latte-wt-p3b, branch p3b-transplants. Method per
docs/captsilver-testability-adoption.md P3b: premise checked against OUR
code first, raised past the fork's cases, negative-tested. Reference:
~/Projects/latte-dock-qt6 at origin/main (read via git show; local
checkout sits at 9003f33a).

## Candidate-by-candidate

### shortcutstest - ADOPTED (16c7a0a92)

Fork: tests/shortcutstest.cpp at origin/main. Premises verified against
app/shortcuts/shortcutstracker.cpp and modifiertracker.cpp (both in
lattedock-core, upstream-shaped, identical parse logic). Raised:
data-driven badge table adds the branches the fork skipped (non-Meta
two-token uppercase, bare token F5, bare lowercase letter uppercased,
entry-19 boundary), multi-widget applet registry case, first-entry-
missing basedOnPosition row. Isolation defect in the FORK'S version
found while transplanting: their test left the session bus live, so
ShortcutsTracker's constructor (clearAllAppletShortcuts -> KGlobalAccel)
registered a throwaway component in the desktop's real kglobalacceld on
every run. Ours neuters DBUS_SESSION_BUS_ADDRESS and points
XDG_CONFIG_HOME at a temp dir BEFORE QGuiApplication (custom main, same
pattern as screenpooltest / askdestroysignalorderingtest).
ModifierTracker coverage stays idle-state only: KModifierKeyInfo key
events cannot be injected headless (same wall the fork hit).

### storagetest - ADOPTED (defect found + fixed first)

DEFECT (fixed in f5a654217, fix(layouts)): Storage::updateView wrote
maxLength at the containment-group level while view() reads it from the
[General] subgroup - a max-length edit routed through view data (Views
dialog, inactive/storage-backed views via viewscontroller.cpp) landed on
a dead key and was lost. Inherited from upstream latte-dock (still live
on their master, verified via invent.kde.org raw fetch). Fork parallel:
their b48903ec is the same fix; their round-trip test caught it.

Test (this commit): drives the real Storage::self() singleton through
lattedock-core over temp .latte fixtures. Raised past the fork: view()
defaults table for unset keys, updateView non-Latte refusal (no
scribbling over foreign containments), clean-layout negative for the
errors/warnings scanners, plugins() containment-id filter made
observable (foreign containment carries its own applet; fork only
asserted rowCount >= 1), exportTemplate additionally pins
isPreferredForShortcuts and the LayoutSettings clearing. Dropped their
importContainmentsCopiesGroups: importContainments is PRIVATE in our
tree (fork widened it); its observable effect is pinned through
newView's inactive-layout branch instead - visibility not widened just
for a test. Learned mid-run: the warnings scanner counts ANY non-Latte
containment reachable from no view as orphaned, so the clean-layout
case needs a fixture without the foreign desktop containment.

## Still to work (P3b order)

universalsettingstest, layoutmanagertest + appletremovaltest,
importerlogictest, layoutsmodeltest + viewsmodeltest + schemesmodeltest,
viewmodelstest, wmtoolstest, commontoolstest/coretoolstest/
generictoolstest, coretypesenumtest, panelbackgroundtest +
configcontrolstest.
