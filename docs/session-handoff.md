# Session handoff

Rolling handoff for the next session to pick up without re-deriving context.
Last updated 2026-07-10. HEAD is 87060e36 on main (plus the docs commit that
adds this file), working tree clean. A staged dock is running against the real
user config via scripts/restart-staged.sh.

## What landed this session (all committed, all live-verified with screenshots)

Edit mode blueprint, done the Qt5-faithful way (the dock draws the grid in its
own window, since two wlr-layer surfaces cannot stack dock > grid > wallpaper):

- d68b8e8d feat(containment): draw the blueprint inside the containment, between
  the dock background and the layouts container, driven by root.editMode.
- d72ee0cd fix(containment): size the grid to latteView.editThickness at the
  screen edge. The dock window is taller than the edit area (parabolic zoom
  headroom: 384px window vs 146px editThickness here), so filling the window
  drew a huge grid far above the dock.
- 608a509e fix(settings): stop CanvasConfiguration.qml drawing its own grid.
  The canvas window stacks in front of the dock; its opaque copy hid every
  applet. Its imageTiler stays (geometry for the wheel MouseArea, opacity value
  for SettingsOverlay text contrast) but no longer renders.
- f5a5f44c fix(editmode): restore Qt5 editBackgroundOpacity semantics. The port
  had rewired the grid opacity to panelTransparency (the dock's persistent
  background setting) with an invented 0.5 floor, so at the theme default it was
  fully opaque and hid the white panel bar. Now: editBackgroundOpacity (default
  0.2), solid while rearranging widgets and without compositing, wheel steps it
  0.1 with no floor.

Wayland window previews (were blank, now show real thumbnails):

- c25cb3e1 fix(plasmoid): port previews to Plasma 6 kpipewire. The 5.26 rung
  kept the kpipewire 5 contract (item created enabled:false, C++ flips it);
  kpipewire 6 does not, so opacity stayed 0. Replaced the whole dead 5.24/5.25/
  5.26 version ladder with plasma-desktop 6's PipeWireThumbnail.qml shape.
  Also winId int -> var in ToolTipWindowMouseArea (wayland ids are QString
  UUIDs; same defect class as 5a77d2da).

Crash + infrastructure:

- 46dc83c5 fix(app): Factory::removeIndicatorRecords called removeAt(-1) for
  built-in indicators (never in the custom lists), a hard SIGSEGV on Qt6 (Qt5
  tolerated it). Fires when the install tree is restaged under a running dock.
  Three coredumps today traced here.
- f24b7d89 build: scripts/restart-staged.sh. Orphaned docks end up SIGSTOPped
  and ignore SIGTERM, so bare pkill left them alive and stacked instances (three
  docks were fighting over layer surfaces at one point). The script TERM+CONT,
  escalates to KILL, refuses to stack, launches via setsid with stdin closed.
- c49db4cc build: scripts/tools/fakepointer.c, wayland pointer injection for
  live verification (see below).
- fcedce40 docs: Qt5-faithful behavior agreement recorded in CLAUDE.md.

## Current task (in progress, NOT started in code): hover preview jitter

User report: hover an app icon, the preview appears; move the cursor a little
left or right and the preview disappears and reappears in a slightly different
spot. The user's instinct is right: it is the parabolic icon zoom repositioning
things under the cursor. This was a "describe the problem" question, so the next
step is to confirm root cause and propose a fix, not to have already fixed it.

What was confirmed by reading the code (not yet fully root-caused or fixed):

- Preview show/hide lives in plasmoid/.../task/TaskMouseArea.qml onEntered
  (line 65) / onExited (line 100). onExited calls root.hidePreview() which runs
  windowsPreviewDlg.hide() -> a 300ms debounce (hidePreviewWinTimer,
  plasmoid/.../main.qml:424). onEntered with previews already visible calls
  taskItem.showPreviewWindow() immediately.
- windowsPreviewDlg.show(taskItem) (main.qml:388) sets activeItem = taskItem and
  the popup anchors to that task's visualParent (set in TaskItem.qml:493). So
  the popup follows whichever task is activeItem.
- Mechanism (hypothesis, needs confirming live): as the cursor moves, parabolic
  zoom animates icon positions/sizes. The hovered icon (or a neighbor) shifts
  under the cursor, the cursor crosses a MouseArea boundary, onExited fires on
  one task and onEntered on the next, show() re-anchors the popup to the new
  task's moved geometry -> the "reappear in a slightly different spot". Even
  same-task, the anchor geometry moves as zoom animates.
- Related and probably the same defect surface: the OLD backlog item "preview
  tooltip mispositions on fast re-hover" -> declarativeimports/core/dialog.cpp
  popupPosition() computes a global point and calls setPosition(), which wayland
  ignores/handles poorly instead of using a proper xdg_popup positioner. The
  janky reposition is likely this.

Starting points for the fix: (a) the 300ms hidePreviewWinTimer debounce; (b) the
show()/showPreviewWindow reposition path re-anchoring on every entered; (c)
dialog.cpp popupPosition() wayland anchoring. Note PORTING_PLAN Phase 7 already
has an "always-visible MouseArea, synchronous parabolic calc" note from
latte-dock-ng (its 0deca9e18) for the zoom-stutter class; read it first.

## The live-verification loop (the big infrastructure win, use it every time)

Do NOT claim a UI change works without driving it and reading pixels. Yesterday's
"blank screenshot, tool is broken" conclusion was wrong; the tooling works.

- Restart the dock ONLY via scripts/restart-staged.sh --user-config -d (never
  bare pkill + relaunch, per the SIGSTOP trap above). It restages QML every run.
- Enter edit mode: busctl --user call org.kde.kglobalaccel /component/lattedock
  org.kde.kglobalaccel.Component invokeShortcut s "show view settings"
- Move/click the pointer without a human: scripts/tools/fakepointer.c
  (move|click <x> <y>) via org_kde_kwin_fake_input. KWin gates that interface
  per client, so it needs a desktop file in ~/.local/share/applications with a
  matching absolute Exec and X-KDE-Wayland-Interfaces=org_kde_kwin_fake_input,
  then kbuildsycoca6. A built binary + fakepointer.desktop are already set up.
- Capture: spectacle -b -n [-p for cursor] -o <file>, then Read the png.
- A ~14KB all-white png means the screen is LOCKED (loginctl show-session
  <wayland session> -p LockedHint) or the display slept, NOT a spectacle flake.
  User gave standing consent to loginctl unlock-session for verification; re-lock
  with loginctl lock-session when done. Run kscreen-doctor --dpms on before
  capturing. The session auto-locks on a timer, so expect to unlock repeatedly.
- Confirm a capture landed inside edit mode by checking the png mtime against the
  dock log's "#primaryconfigview#" init line. The settings window closes on focus
  loss and edit mode dies within seconds of the user typing elsewhere, so capture
  ~2s after the invoke.
- Screenshots and the fakepointer binary go under $CLAUDE_JOB_DIR/tmp, not /tmp.

## Known traps

- Never rebuild (nix develop -c cmake --build build --target latte-dock) while a
  dock runs from build/bin; the running dock then executes a deleted binary and
  crashes confusingly. Stop it first.
- MultiLayered.qml already has a Behavior on opacity at its root; a second one
  logs "Attempting to set another interceptor" and is ignored. Those and the
  ~56 KWindowShadow warnings are pre-existing noise; do not chase them.
- QML/package changes need no rebuild (restart-staged.sh restages). Only C++
  changes (app/, declarativeimports/) need the cmake build.
- Validate QML with nix develop -c scripts/qml-compile-gate.sh before launching.

## Backlog (root-caused where noted, not started)

1. Edit mode step 2 (grow dock to editThickness) is filed in PORTING_PLAN Phase
   7 but may be largely moot: the mask already exposes the full window in edit
   mode and the window is taller than editThickness. Evaluate what actually
   remains (struts, input region, slide-in animation) before wiring anything.
2. UX: when the rearrange toggle is centered, open the settings window to the
   right instead of also centered (app/view/settings/primaryconfigview.cpp).
3. Dock invisible after a screen lock/unlock cycle, and a dock started under a
   locked screen stalls for minutes before "Adding View". Filed in PORTING_PLAN
   Phase 8. Not root-caused.
4. System widgets (system monitor, battery, bluetooth, networkmanagement,
   kdeconnect, dictionary) fail "module not installed": their private QML
   modules are not on the launcher's QML2_IMPORT_PATH. WARNING: a broad append
   of the system Qt6 QML tree fixed them once but shadowed org.kde.taskmanager
   and replaced the dock context menu with the stock one. Allow-list leaf
   modules (symlink specific dirs into a private root), never the shared root.
5. plasma_applet_dict also needs QtWebEngine; recheck after 4.
