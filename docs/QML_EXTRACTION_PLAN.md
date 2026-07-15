# QML extraction plan

Planning artifact for moving behavioral logic out of QML into
strongly-typed, unit-testable C++. Written 2026-07-15 against HEAD
5e1c2b12 by the strong-model planning session named in
docs/prompts/qml-extraction-planning-prompt.md; every commit hash, file
path, and line range cited below was verified with git/grep during that
session. This plan executes across a model transition: specs tagged
`delegate-safe` are written to be executable cold by a weaker model;
specs tagged `strong-model-only` must land inside the remaining
strong-model window or be deferred, never delegated.

Posture (decided in CLAUDE.md as of ce94bb1d, not relitigated here):
maintained continuation. Upstream mergeability is not a constraint.
Non-negotiable: small bisectable commits, Qt5 behavioral fidelity per
extraction (the Qt5 source is in our own history at tag f0ad7b23,
v0.10.8: `git show f0ad7b23:<path>`), re-implementation with
understanding. CaptSilver/latte-dock-qt6 (reviewed through 81384003) is
a blueprint of WHAT to extract and WHICH invariants to pin, never a
source to paste.

## Completeness ledger

Kept current as sections land. A PENDING spec names its scope in one
line; DONE means the full spec is written to the section-C template.

Inventory (section A):
- [x] containment/ - 62 QML files classified
- [x] plasmoid/ - 36 QML files classified
- [x] shell/ - 28 QML files classified
- [x] indicators/ - 9 QML files classified
- [x] declarativeimports/ - 104 QML files classified
- [x] JS logic files addendum - 11 files

Ranking (section B): [x] done.

Per-unit specs (section C), in rank order:
- [ ] EX-01 PreviewSwitchEngine - preview adoption/debounce/LRU decision core
- [ ] EX-02 ParabolicRouter - neighbor scale-stack propagation chains
- [ ] EX-03 ParabolicMathCore - the zoom curve math
- [ ] EX-04 AutoSizeEngine - iconSize shrink/grow feedback loop
- [ ] EX-05 FillLengthDistributor - Justify/fill two-pass space distribution
- [ ] EX-06 VisibleIndexEngine - visible-index math + separator neighbor walks
- [ ] EX-07 StorageIdRemapper - layout-file id remapping (capt blueprint)
- [ ] EX-08 ScreenGeometryCalculator - available screen rect/region (capt blueprint)
- [ ] EX-09 PositionerGeometry - view sizing/placement math (capt blueprint)
- [ ] EX-10 MaskInputGeometry - visibility mask + input region rect math
- [ ] EX-11 LauncherListOps - launcher order algebra, registries, stored-list parsing
- [ ] EX-12 ColorizerDecisionCore - applyTheme/scheme selection tree
- [ ] EX-13 ViewTypeAndBackgroundPredicates - Panel-vs-Dock chain + background states
- [ ] EX-14 DropEventClassifier - drag mime classification + insert index
- [ ] EX-15 WheelAccumulator - wheel delta accumulation/threshold semantics
- [ ] EX-16 GroupWindowCycler - next/previous/minimize target selection
- [ ] EX-17 TooltipTextComposer - preview title/subtext string transforms
- [ ] EX-18 LengthOffsetClamp - maxLength/offset mutual clamp (dedup)
- [ ] EX-19 ColorLuminance - shared brightness/luminance helpers (dedup)
- [ ] EX-20 BadgeMath - badge parsing, proportion, arc geometry
- [ ] EX-21 ScrollOverflowMath - scrollable list overflow/autoscroll math
- [ ] EX-22 ActivitySetAlgebra - activity set filtering (capt blueprint)
- [ ] EX-23 WindowTrackingPredicates - window predicate + extra-view-hints pass (capt blueprint)
- [ ] EX-24 IconSourceClassifier - icon source classification (capt blueprint)
- [ ] EX-25 PanelBackgroundScan - panel background scanline math (capt blueprint)

Section D (coverage + ratchet): [ ] pending.
Section E (waves): [ ] pending.
Section F (risks + non-goals): [ ] pending.
Executive summary: [ ] pending.
PORTING_PLAN cross-reference item: [ ] pending.

## Method

- Extraction shape (the capt shape, proven in our own tree by
  d12baff2's `declarativeimports/core/dialog.cpp` seam and by
  `containment/plugin/layoutmanager.cpp`): a pure core - plain value
  structs in, plain values out, no QObject/scenegraph/binding
  dependencies - plus, where QML must call it, a thin registered
  wrapper in the subsystem's existing C++ plugin. Tests include the
  core header directly; the existing qmltest/contract harness keeps
  driving the real shipped QML for the thin-shell wiring.
- Cutover per unit, never two live copies: the commit that lands the
  C++ core also switches the QML call site to it and deletes the QML
  body. Bisectability is the rollback story; a revert of one commit
  restores the QML logic wholesale.
- Qt5 fidelity per unit: each spec names the f0ad7b23 file the C++
  must match. Where the port already fixed a Qt5-era defect (e.g.
  ad9b823f's loop termination), the spec says which behavior wins and
  why; everything else matches Qt5 exactly, tested by cases derived
  from reading the Qt5 body at execution time.
- No bandaids carried over: where the QML logic "works" via a polling
  timer, silent early-return, or value-hiding clamp, the spec flags it
  as a defect to fix during extraction. The known inventory of
  assessed silent guards is in docs/session-handoff.md (the 2026-07-15
  loops/degenerate-indexes sweep); specs reference it rather than
  re-litigating each guard.

## A. QML logic inventory

Classification taxonomy: geometry-math / state-machine / ordering /
model-transform / event-routing / pure-presentation. Size is the
extractable behavioral-logic volume: S under 40 lines, M 40-150, L
over 150. Verdict BEHAVIORAL means extraction candidate (section B/C
decides extract vs pin-in-place); PRESENTATIONAL means leave in QML.
File classifications were produced by four read-only inventory
subagent sweeps over every file; function names quoted here were
re-verified by grep in the main session wherever a spec cites them.
Line numbers appear only in section C, individually verified.

### containment/ (62 files, 13159 lines)

Behavioral files:

| File (containment/package/contents/ui/) | Lines | Categories | Size |
| --- | --- | --- | --- |
| main.qml | 1232 | geometry-math, state-machine, event-routing, ordering | L |
| VisibilityManager.qml | 661 | geometry-math, state-machine | L |
| BindingsExternal.qml | 399 | geometry-math, model-transform | L (borderline; most bindings are passthrough) |
| DragDropArea.qml | 206 | event-routing, state-machine | M |
| applet/AppletItem.qml | 1122 | geometry-math, state-machine, ordering, event-routing | L |
| applet/ItemWrapper.qml | 742 | geometry-math, state-machine | L |
| applet/ParabolicArea.qml | 244 | geometry-math, event-routing | L |
| applet/EventsSink.qml | 203 | geometry-math, event-routing | M (borderline) |
| applet/HiddenSpacer.qml | 72 | geometry-math | S (borderline) |
| applet/IndicatorLevel.qml | 77 | geometry-math, event-routing | S (borderline) |
| applet/ShortcutBadge.qml | 102 | model-transform | S (borderline) |
| applet/communicator/Actions.qml | 56 | event-routing | S (borderline) |
| abilities/AutoSize.qml | 258 | geometry-math, state-machine, event-routing | L |
| abilities/Metrics.qml | 103 | geometry-math | M |
| abilities/ParabolicEffect.qml | 38 | geometry-math | S (borderline) |
| abilities/Layouter.qml | 72 | state-machine, event-routing | S |
| abilities/Indexer.qml | 64 | ordering, model-transform | M |
| abilities/Animations.qml | 53 | state-machine | S (borderline) |
| abilities/PositionShortcuts.qml | 52 | event-routing | S |
| abilities/Indicators.qml | 125 | model-transform | M (borderline; capability probing) |
| abilities/privates/IndexerPrivate.qml | 312 | ordering, model-transform | L |
| abilities/privates/LayouterPrivate.qml | 440 | geometry-math, ordering | L |
| abilities/privates/layouter/AppletsContainer.qml | 214 | model-transform, ordering | L |
| abilities/privates/MetricsPrivate.qml | 144 | geometry-math | M |
| abilities/privates/ParabolicEffectPrivate.qml | 158 | state-machine, event-routing | L |
| abilities/privates/AnimationsPrivate.qml | 64 | model-transform | S |
| abilities/privates/LaunchersPrivate.qml | 113 | model-transform | M (borderline; duplicated 3-layout scans) |
| abilities/privates/MyViewPrivate.qml | 95 | model-transform, state-machine | M (borderline) |
| abilities/privates/PositionShortcutsPrivate.qml | 78 | model-transform | S (borderline) |
| abilities/privates/ThinTooltipPrivate.qml | 56 | model-transform | S (borderline) |
| background/MultiLayered.qml | 951 | geometry-math, state-machine | L (the ~300-line states block is presentational) |
| background/types/Paddings.qml | 40 | geometry-math | S (borderline) |
| background/types/Shadows.qml | 49 | geometry-math | S (borderline) |
| background/types/Totals.qml | 51 | geometry-math | S (borderline) |
| colorizer/Manager.qml | 206 | state-machine, model-transform | L |
| colorizer/CustomBackground.qml | 237 | geometry-math | M |
| editmode/ConfigOverlay.qml | 564 | geometry-math, state-machine, event-routing, ordering | L |
| layouts/LayoutsContainer.qml | 537 | geometry-math, state-machine, event-routing | L |
| layouts/EnvironmentActions.qml | 360 | geometry-math, event-routing | L |
| layouts/ParabolicEdgeSpacer.qml | 122 | geometry-math, event-routing | M |
| layouts/loaders/Tasks.qml | 102 | ordering, model-transform | M |

Presentational (leave in QML): abilities/Launchers.qml (thin proxy to
layoutsManager.syncedLaunchers), abilities/MyView.qml, abilities/Debug.qml,
abilities/ThinTooltip.qml, abilities/UserRequests.qml,
abilities/privates/IndicatorsPrivate.qml (mirror bindings),
abilities/privates/metrics/Fraction.qml, applet/PaddingsInConfigureApplets.qml,
applet/TitleTooltipParent.qml, applet/EventsSinkOriginArea.qml,
applet/colorizer/Applet.qml, applet/communicator/LatteBridge.qml,
applet/communicator/Engine.qml (logic lives in AppletIdentifier.js),
background/BackgroundProperties.qml, colorizer/KirigamiShadowedRectangle.qml,
colorizer/NormalRectangle.qml, debugger/DebugWindow.qml (861 lines of
read-only diagnostics display), debugger/Tag.qml, layouts/AppletsContainer.qml,
Upgrader.qml (one-shot v0.10 config migration), ContextMenuLayer.qml.

### plasmoid/ (36 files, 9858 lines)

Behavioral files:

| File (plasmoid/package/contents/ui/) | Lines | Categories | Size |
| --- | --- | --- | --- |
| main.qml | 1698 | state-machine, model-transform, ordering, geometry-math, event-routing | L |
| TasksExtendedManager.qml | 404 | model-transform, ordering, state-machine | L |
| PulseAudio.qml | 127 | model-transform, geometry-math | M |
| ContextMenu.qml | 909 | model-transform, event-routing, ordering | L |
| task/TaskItem.qml | 996 | state-machine, model-transform, geometry-math, event-routing | L |
| task/TaskIcon.qml | 593 | state-machine, pure-presentation | M (borderline; effect gating) |
| task/TaskMouseArea.qml | 375 | event-routing, state-machine | L |
| task/SubWindows.qml | 310 | model-transform, ordering, state-machine | L |
| task/AudioStream.qml | 147 | event-routing, geometry-math | M |
| task/ProgressOverlay.qml | 114 | model-transform | S (borderline) |
| task/animations/RealRemovalAnimation.qml | 226 | state-machine, ordering, event-routing | M |
| task/animations/ShowWindowAnimation.qml | 201 | state-machine, ordering | M |
| task/animations/RemoveWindowFromGroupAnimation.qml | 147 | state-machine, geometry-math | S |
| task/animations/NewWindowAnimation.qml | 104 | state-machine | S |
| task/animations/LauncherAnimation.qml | 113 | state-machine | S |
| taskslayout/ScrollableList.qml | 382 | geometry-math, ordering, state-machine | M |
| taskslayout/MouseHandler.qml | 264 | event-routing, ordering, model-transform | M |
| previews/ToolTipInstance.qml | 524 | model-transform, geometry-math, event-routing | L |
| previews/ToolTipDelegate2.qml | 234 | model-transform, geometry-math, event-routing | M |
| previews/ToolTipWindowMouseArea.qml | 51 | event-routing | S |
| abilities/Launchers.qml | 404 | model-transform, ordering, event-routing, state-machine | L |
| abilities/launchers/Validator.qml | 137 | ordering, model-transform | M |
| abilities/launchers/Syncer.qml | 109 | event-routing, state-machine | S |

Presentational (leave in QML): task/animations/launcher/BounceAnimation.qml,
task/animations/newwindow/BounceAnimation.qml,
task/animations/ClickedAnimation.qml, taskslayout/ScrollEdgeShadows.qml,
taskslayout/ScrollOpacityMask.qml, taskslayout/ScrollPositioner.qml,
previews/PipeWireThumbnail.qml, previews/PlasmaCoreThumbnail.qml,
AppletAbilities.qml, config/ConfigAppearance.qml (index-value combo
mapping is UI-local), config/ConfigInteraction.qml, config/ConfigPanel.qml,
and plasmoid/package/contents/config/config.qml.

### shell/ (28 files, 7720 lines)

Behavioral files:

| File (shell/package/contents/) | Lines | Categories | Size |
| --- | --- | --- | --- |
| applet/CompactApplet.qml | 444 | state-machine, geometry-math, event-routing | L |
| configuration/CanvasConfiguration.qml | 190 | geometry-math, event-routing | M |
| configuration/LatteDockConfiguration.qml | 656 | geometry-math, model-transform, state-machine, event-routing | L |
| configuration/canvas/HeaderSettings.qml | 170 | geometry-math | M |
| configuration/canvas/maxlength/RulerMouseArea.qml | 77 | geometry-math, event-routing | M |
| configuration/canvas/maxlength/Ruler.qml | 324 | geometry-math | M |
| configuration/pages/AppearanceConfig.qml | 1232 | geometry-math, model-transform, event-routing | L |
| configuration/pages/BehaviorConfig.qml | 937 | model-transform, ordering, event-routing | M |
| controls/CustomIndicatorButton.qml | 215 | model-transform, event-routing, state-machine | L |
| controls/CustomVisibilityModeButton.qml | 129 | model-transform, ordering, event-routing | M |
| controls/DragCorner.qml | 167 | geometry-math, event-routing | M |
| controls/IndicatorConfigUiManager.qml | 135 | state-machine, ordering, event-routing | M |
| controls/TypeSelection.qml | 136 | model-transform, event-routing | M |
| views/AppletDelegate.qml | 229 | event-routing | S |
| views/Panel.qml | 128 | state-machine, event-routing | M |
| views/WidgetExplorer.qml | 537 | model-transform, event-routing, state-machine | L |

Presentational (leave in QML): configuration/config.qml,
configuration/LatteDockSecondaryConfiguration.qml,
configuration/canvas/SettingsOverlay.qml,
configuration/canvas/controls/Button.qml, GraphicIcon.qml,
RearrangeIcon.qml, StickIcon.qml, configuration/pages/EffectsConfig.qml
(control-to-config plumbing), configuration/pages/TasksConfig.qml
(control-to-config plumbing; the Plasma 6 config-access route it uses
is pinned by 32df5b47), controls/InnerShadow.qml,
explorer/AppletAlternatives.qml (the 56549d73 package-local copy;
deliberately kept a minimal-diff mirror of plasma-desktop's file),
views/InfoView.qml.

### indicators/ (9 files, 1513 lines)

Behavioral: default/package/ui/main.qml (318 lines; geometry-math,
state-machine; L - mask thickness math, W3C luminance color selection,
line-style grow/shrink animation state machine),
org.kde.latte.plasma/package/ui/FrontLayer.qml (267 lines;
geometry-math, event-routing; M - clicked-animation radius math,
per-edge press-coordinate conversion),
org.kde.latte.plasma/package/ui/main.qml (145 lines; model-transform,
geometry-math; M - progress clip math, SVG prefix arrays).

Presentational: default/package/config/config.qml (percent-conversion
plumbing; carries the 33fa17d7 latteIndicator alias),
org.kde.latte.plasma/package/config/config.qml,
org.kde.latte.plasma/package/ui/AppletBackLayer.qml,
org.kde.latte.plasma/package/ui/TaskBackLayer.qml,
org.kde.latte.plasmatabstyle/package/ui/BackLayer.qml,
org.kde.latte.plasmatabstyle/package/ui/main.qml.

### declarativeimports/ (104 files, 7671 lines)

declarativeimports/core is C++ only (no QML). Behavioral files:

| File (declarativeimports/) | Lines | Categories | Size |
| --- | --- | --- | --- |
| components/ComboBox.qml | 476 | model-transform, event-routing, geometry-math | M |
| components/BadgeText.qml | 179 | geometry-math, event-routing | M |
| components/Slider.qml | 127 | geometry-math | S |
| components/SpriteRectangle.qml | 113 | geometry-math | M |
| components/GlowPoint.qml | 344 | geometry-math | S |
| components/ComboBoxButton.qml | 157 | event-routing | S |
| components/TextField.qml | 129 | state-machine, geometry-math | S |
| components/IndicatorItem.qml | 138 | state-machine | S |
| components/ShadowedItem.qml | 50 | geometry-math (delegates to code/EffectMath.js) | S |
| abilities/bridge/PositionShortcuts.qml | 53 | event-routing | S |
| abilities/bridge/ParabolicEffect.qml | 42 | event-routing | S |
| abilities/bridge/Launchers.qml | 37 | event-routing | S |
| abilities/client/Indexer.qml | 243 | ordering, model-transform | L |
| abilities/client/ParabolicEffect.qml | 201 | event-routing, state-machine | M |
| abilities/client/indicators/LatteIndicator.qml | 307 | geometry-math, state-machine | M |
| abilities/client/AppletAbilities.qml | 152 | model-transform, ordering | S |
| abilities/client/PositionShortcuts.qml | 69 | ordering | S |
| abilities/client/UserRequests.qml | 48 | event-routing | S |
| abilities/client/Requirements.qml | 62 | event-routing | S |
| abilities/definition/ParabolicEffect.qml | 82 | geometry-math, ordering | M (the parabolic math core) |
| abilities/definition/animations/Tracker.qml | 26 | model-transform | S |
| abilities/host/ThinTooltip.qml | 135 | state-machine, event-routing | M |
| abilities/host/Containment.qml | 46 | ordering | S |
| abilities/items/BasicItem.qml | 444 | ordering, state-machine, geometry-math, event-routing | L |
| abilities/items/basicitem/ParabolicItem.qml | 285 | geometry-math, state-machine, event-routing | L |
| abilities/items/basicitem/ParabolicEventsArea.qml | 225 | event-routing, geometry-math, ordering | L |
| abilities/items/IndicatorObject.qml | 119 | state-machine | S |
| abilities/items/basicitem/HiddenSpacer.qml | 102 | geometry-math, state-machine | S |
| abilities/items/basicitem/ShortcutBadge.qml | 88 | ordering | S |
| abilities/items/basicitem/IndicatorLevel.qml | 54 | event-routing, geometry-math | S |

Presentational (leave in QML), 74 files: components/HeaderSwitch.qml,
ItemDelegate.qml, ExternalShadow.qml, AddItem.qml, ScrollArea.qml,
SpinBox.qml, Header.qml, SubHeader.qml, Label.qml, CheckBox.qml,
CheckBoxesColumn.qml, Switch.qml, ToolTip.qml, AddingArea.qml, all six
components/private/ files, abilities/bridge/BridgeItem.qml, Indexer.qml,
Animations.qml, MyView.qml, ThinTooltip.qml, abilities/client/
Animations.qml, MyView.qml, Metrics.qml, Indicators.qml, ThinTooltip.qml,
Containment.qml, Debug.qml, Environment.qml, all three
appletabilities/Container*Bindings.qml, indicators/LatteConfiguration.qml,
all 27 abilities/definition/ interface files except the two behavioral
ones above, all abilities/host/ publicApi surfaces except ThinTooltip
and Containment, abilities/items/basicitem/SeparatorItem.qml,
TitleTooltipParent.qml, RestoreAnimation.qml,
abilities/items/IndicatorLevel.qml, indicators/LevelOptions.qml.

### JS logic files addendum (11 files, 1206 lines)

The .qml sweeps exclude imported .js libraries; they are part of the
same extraction surface:

- containment/package/contents/code/autosize.js (58) - shrinkStep/
  growStep math for EX-04.
- plasmoid/package/contents/code/layout.js (193) - plasmoid layout
  helpers.
- plasmoid/package/contents/code/tools.js (121) - task helper
  predicates.
- plasmoid/package/contents/code/TaskActions.js (56) - task action
  token dispatch tables.
- plasmoid/package/contents/code/activitiesTools.js (357) - launcher
  activity migration helpers.
- containment/package/contents/code/AppletIdentifier.js (304) -
  applet-specific icon discovery heuristics.
- three copies of ColorizerTools.js (34+34+28: declarativeimports/
  components/code/, containment/package/contents/code/,
  plasmoid/package/contents/code/) - the luminance math EX-19
  deduplicates.
- declarativeimports/components/code/EffectMath.js (10) - shadow blur
  curve.
- containment/package/contents/code/MathTools.js (11).

## B. Hot-spot ranking

Three axes. Bug-density counts verified fix commits whose diffs touch
the unit's logic (hashes cited; counted over f0ad7b23..HEAD with
`git log --grep='^fix' --name-only`). Testability-gain estimates how
much currently-unpinnable behavior becomes table-testable.
Feel-risk orders live-verification weight; high feel-risk sequences
later within its wave and gets a mandatory live recipe.

1. Preview adoption/anchoring pipeline (plasmoid main.qml previews
   block, TaskItem preview functions). Bug density 15+, the densest in
   the tree, all 2026-07-13..15: c6eeeb20, 4f96acb8, 4b533b8d,
   54ed1974, 0913bbee, 235753b8, d56a26aa, f1edd103, d619ae08,
   15558f40, e6c5ae76, c622da1b, d98bff98, 77aac4b4, df747ebf. Ten
   line-level invariants currently pinned only by grep
   (scripts/preview-contract-rules.sh, b4f5621c). Testability-gain:
   highest. Feel-risk: highest (hover feel, measured in ms).
   -> EX-01, strong-model-only.
2. Parabolic zoom engine (definition/ParabolicEffect.qml math;
   propagation chains in ParabolicEventsArea/ParabolicArea/
   ParabolicEdgeSpacer/ParabolicEffectPrivate). Direct fix density low
   in this port (the zoom math itself is untouched since fork), but
   the propagation index arithmetic is the exact class the
   loops/degenerate-values sweep hunted, the glide-vs-jump
   verification hazard cost hours of phantom flakiness (2026-07-15,
   recorded in latte-live-verification), and every hover bug transits
   this code. Feel-risk: maximum of the whole plan.
   -> EX-02 (router, strong-model-only) + EX-03 (math, delegate-safe).
3. AutoSize feedback loop (abilities/AutoSize.qml + code/autosize.js).
   Density: ad9b823f (infinite loop, 100% CPU hang, inherited
   upstream defect from 747d4870-era code). Already partially pinned
   by tests/qml/tst_autosize.qml. Pure math + bounded history: very
   high testability. -> EX-04, delegate-safe.
4. Fill/Justify length distribution (LayouterPrivate.qml). Zero direct
   fixes in our tree, but latte-dock-ng fixed a dock collapse in the
   same inherited algorithm (ng 30637c1cd) and the two-pass
   distribution is exactly the shape unit tests eat. -> EX-05,
   delegate-safe.
5. Visible-index and separator-neighbor ordering (IndexerPrivate.qml,
   client Indexer.qml twin, AppletItem/BasicItem neighbor walks).
   The 2026-07-15 loops sweep verified all these while-loops terminate
   (clean negatives, recorded in session-handoff) but nothing pins the
   RESULTS; the twins have already drifted apart structurally.
   -> EX-06, delegate-safe.
6. Storage id remapping (app/layouts/storage.cpp, C++). Density:
   fa02b887 (containments destroyed during template import; its
   liveness filter is a self-admitted band-aid with the deleter still
   unidentified), plus the whole duplicate-flow saga rode this path
   (e412889d investigation). capt extracted this exact unit
   (73f64383). -> EX-07, delegate-safe.
7. Available screen geometry (app/lattecorona.cpp, C++). Density:
   1b932ed9 (settings window overflow; our fix deliberately DIVERGES
   from upstream d30143f7 by accepting self-origin updates - the
   extraction must preserve that deviation). capt blueprint:
   screengeometrycalculator (with tests). -> EX-08, delegate-safe.
8. Positioner geometry (app/view/positioner.cpp, C++). Density: 3
   fixes (793faad2 moveToScreen remap, c5bdc239 late screen id,
   1607d022 family). capt blueprint: 4a829185. Our architecture
   note: on Wayland much placement authority moved to layer-shell
   anchors (app/wm/waylandlayershell.cpp), so the pure math matters
   mainly for X11, masks, and the canvas/edit chrome rects.
   -> EX-09, delegate-safe.
9. Visibility mask + input geometry (containment
   VisibilityManager.qml). Related family: the canvas input-region
   work (3d714d63, dbe5a03b) lives in C++ already; the QML half
   computes the dock's own mask/input rects. Errors here are
   invisible-dock / dead-input bugs. -> EX-10, delegate-safe with a
   heavy live recipe.
10. Launcher ordering complex (abilities/Launchers.qml,
    launchers/Validator.qml, TasksExtendedManager.qml). Density:
    d6d57e61 (stale synced-launcher clients crash); the Validator's
    upwardIsBetter -1-splice heuristic is in the assessed-guards
    inventory. Pure list algebra throughout. -> EX-11, delegate-safe.
11. Colorizer decision tree (colorizer/Manager.qml). The color complex
    (1f835402, 5c06b497, 79ca3360) was effects- and measurement-side,
    but every one of those investigations had to re-derive this
    QML decision tree to reason about expected behavior. -> EX-12,
    delegate-safe.
12. viewType/background predicate chain (containment main.qml,
    MultiLayered.qml). Density: 38e60eb9, f5a5f44c, d72ee0cd (the
    edit-mode background family) plus the recurring throwaway-layout
    confusion (viewType=1 rendering full-width background, mistaken
    for a regression twice in session-handoff). -> EX-13,
    delegate-safe.
13. Drop classification and insert index (DragDropArea.qml,
    MouseHandler.qml). Density: b474adad (the DropArea dead-handler
    trap was found here). -> EX-14, delegate-safe.
14. Wheel semantics (AudioStream.qml, TaskMouseArea.qml,
    EnvironmentActions.qml, RulerMouseArea.qml). Density: 299a241b
    (audio wheel matched to plasma-pa exactly, hand-verified).
    -> EX-15, delegate-safe.
15. Remaining pure-transform tail, all delegate-safe: EX-16 group
    cycling (SubWindows.qml + loaders/Tasks.qml), EX-17 preview
    title/subtext transforms (ToolTipInstance.qml), EX-18
    maxLength/offset clamp dedup (RulerMouseArea.qml vs
    AppearanceConfig.qml, two live copies of the same math), EX-19
    luminance dedup (five copies counted), EX-20 badge math, EX-21
    scroll overflow math, and the four remaining capt C++ blueprints
    EX-22..EX-25.

De-prioritized (high visibility, low extraction value): purely-drawing
QML (the states blocks, gradients, shadows), the ability
bridge/host/definition relay layers (property plumbing, no logic), the
settings pages' control-to-config plumbing (single-loader doctrine
already pinned by 32df5b47/c3d15966 fixes and their tests).

Pin-in-place verdicts (behavioral in the inventory, but extraction is
the wrong tool; each becomes a test-only task, not a backlog unit):

- shell CompactApplet.qml popup sizing/representation chain. Fix
  density is real (437d9a0c, 1aa5238c, 9ea29eaa, 5f8c10be, d12baff2)
  but every fix was about matching libplasma's live binding/parenting
  contracts, which is inherently scenegraph-coupled; the chain is
  already pinned by tests/qml/tst_compactapplet.qml (3b37750b) driving
  the real shipped file. Extracting the arithmetic would leave the
  risk (the wiring) in QML and fight the existing pin. Task: extend
  tst_compactapplet when the chain changes; nothing to extract.
- plasmoid ContextMenu.qml (909 lines). Menu assembly against live
  PlasmaExtras.Menu/TasksModel APIs; the one algorithmic piece (the
  eliding while-loop) was verified terminating in the loops sweep. The
  practical hazards here have been API-contract ones (52c2987b menu
  teardown, d67e635a/56549d73 alternatives chain), each now fixed at
  its origin. Task: qmltest contract for loadDynamicLaunchActions
  section assembly if churn resumes.
- editmode/ConfigOverlay.qml drag/reorder. Binding-entangled
  (hoveredItem hit-testing, live reparenting, input-mask re-carve
  8be2b388); recent fixes (36160c46, 8f821310) are stable and
  live-verified. Extraction would need a designed seam for the
  drag session state; flagged design-first in section F, not forced.
- TaskItem slotPublishGeometries. Geometry clamp math feeding
  libtaskmanager; depends on live item mapping (mapToGlobal) per
  frame. Task: add invariant assertions to a qmltest against the real
  TaskItem (bounds containment, hidden-view collapse).
- components/ComboBox.qml role resolution. Already fixed and
  regression-tested (a302d742 covers the three model kinds).
- LatteDockConfiguration.qml window size negotiation. Chrome-only,
  stable since 1b932ed9 fixed the C++ availability side.
- class-A stranded-binding reasserts (e412889d, eca51ae0 and the
  eca51ae0-family reassert functions in plasmoid main.qml). These are
  QML binding lifecycle countermeasures, not extractable logic; the
  open question (what destroys the bindings) is a filed watch item in
  the plan. Extraction note: EX-units that absorb the values these
  bindings feed (EX-10 mask geometry) reduce the surface, which is the
  real fix direction.

<!-- SECTIONS C-F LAND BELOW; the ledger above tracks what is written. -->
