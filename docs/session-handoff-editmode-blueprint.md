# Session handoff: Qt5-faithful edit mode blueprint

Written 2026-07-09 at the end of a long session, for the next session to pick up
without re-deriving context. HEAD is e7add2b3 on main, working tree clean, the
dock is running via scripts/run-staged.sh against the real user config.

## What just landed (committed, user-verified)

- 2c8a27e4 fix(settings): bind "plasmoid" context property to the containment,
  not AppletQuickItem. On Plasma 6 the graphics item has no .configuration, so
  the whole config QML read from undefined. Edit Dock works again.
- 5a77d2da fix(tasks): SubWindows.qml lastActiveWinInGroup int -> var. Wayland
  window ids are QString UUIDs; the int property threw on every hover.
- 516d69ce fix(run-staged): QT_PLUGIN_PATH now points at the staged plugin tree
  so plasma/containmentactions/org.kde.latte.contextmenu loads. Without it the
  right-click menu fell back to the stock task menu.
- e7add2b3 docs: regression discipline guidelines in CLAUDE.md (blast radius of
  env/path changes, verify causation, confirm against the live artifact).

## The task: edit mode blueprint, done the way Qt5 Latte did it

User decision (explicit): do the real Qt5 fix, not an overlay compromise.

In Qt5 Latte, edit mode was the dock transforming itself in one window:
the dock grew to editThickness, and the blueprint grid was drawn inside the
containment behind the applets. Icons stayed crisp on top, and the whole thing
slid in from the screen edge as one motion.

The port instead created a separate CanvasConfigView wlr-layer surface next to
the dock and never grew the dock. Every observed symptom follows from that:

- Measured on the live dock (bottom edge, 2560x1440):
  canvasGeometry = QRect(0,1294 2560x146), editThickness = 146,
  dockAbsGeom = QRect(516,1352 1528x88). The 146px canvas overhangs the 88px
  dock, so the grid shows as a band above the dock.
- The gap between band and dock was the dock's own exclusive zone pushing the
  bottom-anchored canvas out of the reserved strip.
- setExclusiveZone(-1) on the canvas closed the gap but put the grid IN FRONT
  of the dock, hiding it. Reverted. Two wayland layer surfaces cannot be
  interleaved: there is no way to stack dock > grid > wallpaper across two
  surfaces. The grid must live inside the dock window.
- latteView.editThickness is computed in C++ (app/view/view.cpp:1059) but
  consumed NOWHERE in QML. The port simply dropped that wiring.

## The plan (agreed with the user)

Step 1, low risk, do first: draw the blueprint inside the containment.
In containment/package/contents/ui/main.qml, inside backDropArea (around lines
814-830), between Background.MultiLayered and Layouts.LayoutsContainer, add a
tiled Image:
- source: latteView.layout.background (absolute path to the layout's
  print/blueprint jpg, resolved by GenericLayout::background(),
  app/layout/genericlayout.cpp:169)
- fillMode: Image.Tile, opacity/visible driven by root.editMode
  (main.qml:112, = Plasmoid.userConfiguring); consider hiding it in
  root.inConfigureAppletsMode (main.qml:176) like the canvas does
- keep it behind layoutsContainer so icons render on top
QML-only, no rebuild, restage + relaunch to test. Verify with the user before
step 2.

Step 2, geometry-sensitive, do second: grow the dock to editThickness in edit
mode. Wire latteView.editThickness into the containment's metrics/mask:
containment/package/contents/ui/abilities/Metrics.qml,
abilities/privates/MetricsPrivate.qml, and VisibilityManager.qml, gated on
root.editMode. This gives the blueprint full Qt5 height, room above the icons,
and the slide/grow-from-edge entry animation. Expect iteration on mask, strut
and input region.

Step 3, cleanup: stop CanvasConfiguration.qml
(shell/package/contents/configuration/CanvasConfiguration.qml) from drawing its
own imageTiler grid so there is only one blueprint. The canvas window keeps its
other jobs (settings chrome, input carving in configure-applets mode).

Also requested by the user, smaller UX item: when the rearrange toggle is
centered, the settings window should open to the right side instead of also
being centered (app/view/settings/primaryconfigview.cpp places it).

## Known traps (all hit this session)

- MultiLayered.qml already has a Behavior on opacity at its root (line ~40).
  Adding another one logs "Attempting to set another interceptor" and is
  ignored. 56 such warnings are pre-existing noise from elsewhere; do not
  chase them.
- Never rebuild while an instance runs from build/bin; the running dock then
  executes a deleted binary and crashes confusingly on next interaction.
- Kill with pkill -x latte-dock, never -f (matches and kills the launcher).
- app/main.cpp enforces KDBusService::Unique: the old instance must be fully
  gone before relaunch or the new one exits silently ("I don't see a dock").
  A working restart script from this session:
    pkill -x latte-dock; loop until pgrep -x latte-dock is empty;
    exec nix develop -c scripts/run-staged.sh --user-config -d
- Build: nix develop -c cmake --build build --target latte-dock -j$(nproc).
  QML/package changes need no rebuild; run-staged.sh restages on every launch.
- The dock logs go wherever the launcher redirects stdout/stderr; grep those
  logs before theorizing (regression discipline section in CLAUDE.md).

## Backlog beyond the blueprint (root-caused, not started)

1. Hover window previews are blank: the preview dialog opens but
   PipeWireThumbnail / TaskManager.ScreencastingRequest produces no frames on
   wayland. Deep; separate pass.
2. Preview tooltip mispositions on fast re-hover:
   declarativeimports/core/dialog.cpp popupPosition() computes a global point
   and calls setPosition(), which wayland ignores. Needs real popup anchoring.
3. System widgets (system monitor, battery, bluetooth, networkmanagement,
   kdeconnect, dictionary) fail with "module not installed": their private QML
   modules are not on the launcher's QML2_IMPORT_PATH. WARNING: a broad append
   of /run/current-system/sw/lib/qt-6/qml fixed them but shadowed
   org.kde.taskmanager and replaced the dock context menu with the stock task
   menu. The fix must allow-list leaf modules (e.g. symlink the specific
   module dirs into a private import root), never add the shared tree root.
4. plasma_applet_dict also needs QtWebEngine, which appeared reachable via the
   user profile; recheck after 3.
