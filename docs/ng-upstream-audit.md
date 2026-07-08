# Upstream ng commit audit

Walk ruizhi-lab/latte-dock-ng's substantive commits and decide, per commit,
whether this from-scratch port already has the change, should port it, or can
skip it. Goal: don't miss a useful upstream fix.

**Upstream at audit time:** `origin/main` @ `e94a9ce95` (v1.2.24, 2026-07-05).
439 commits since the 2026-05-03 history reset ("Latte Dock NG maintained by
Ruizhi"). 249 are substantive (fix / feat / build / ui); test-only, release,
chore, docs, ci and pure refactor are excluded per the agreed scope.

**Verdicts:**
- **HAVE** — our port already has the equivalent change or behavior.
- **PORT** — missing and worth porting (actionable follow-up).
- **SKIP** — missing but not needed (ng-specific, superseded by our design, or irrelevant).
- **N/A** — test-only / infra / does not apply to the port.
- **CHECK** — needs a closer code or live look before deciding.

Our port paths mirror ng's (`plasmoid/package/contents/ui/...`, `app/view/...`),
so "HAVE" means the specific fix is present in our file, not just that the file
exists. Where our port deliberately took latte-dock-qt6's QML instead of ng's,
that is called out.

**Progress: 13 / 249 audited.**

**Emerging finding (after 13):** only 1 of the first 13 (`internalAction`) is
present. Our port appears to predate ng's May–July 2026 fix wave (indicator
theming, communicator/P6 bridge, audio-badge input handlers, context-menu
hardening, hover-highlight). Expect many PORT/CHECK verdicts. If this holds, the
takeaway is less "cherry-pick a few fixes" and more "our port branched early and
is materially behind ng on task/indicator polish" — which bears on the
fork-adoption decision.

## Audit log

<!-- Append batches below. Format per row:
| short-hash | date | subject | VERDICT | note | -->

| commit | date | subject | verdict | note |
|--------|------|---------|---------|------|
| 990987d93 | 2026-05-03 | feat(ui): app-name hover tooltip fallback | PORT? | Our `task/TaskItem.qml:46` is still ng's exact pre-fix line `isWindow ? model.display : model.AppName`; missing the AppName-first fallback + `thinTooltipActive`/`fallbackTooltipText`. Optional dock-style UX (show app name, not window title). |
| af6a90767 | 2026-05-03 | fix(contextmenu): harden More Places callback | PORT | Our `ContextMenu.qml:320` still has ng's pre-fix inline `backend.showAllPlaces.connect(...)` unguarded. ng moved it to a guarded `Connections` property (prevents null deref / double-connect). Minor robustness. |
| 2d130fed6 | 2026-05-03 | fix(audio): prevent stuck mute badge highlight | PORT | Our `task/AudioStream.qml` still uses the old `audioBadgeMouseArea` MouseArea; ng migrated to `HoverHandler`+`TapHandler` to fix a stuck mute-badge highlight. Real bug fix. |
| 5f0245539 | 2026-05-04 | fix(tasks): restore hover highlight, clear stuck highlight after click | CHECK | Our port lacks `visualContainsMouse` / `clearParabolicFromExternalPosition` entirely — different parabolic-hover impl (qt6-derived). Verify live whether our tasks show the stuck-highlight-after-click bug this fixes. |
| adde24b14 | 2026-05-04 | fix(indicators): panel-contrast task state colors | PORT | Indicator theming cluster (with f559f521b, 74a2f9ef2). Our port has no `textColorSafe`/`backgroundColorSafe`/`panelPalette`/`oppositeToBackgroundColor` anywhere. Indicators likely use wrong contrast on custom panel colors. |
| 8410b0400 | 2026-05-04 | tasks: allow non-pinned into pinned area via auto-pin | CHECK | `schedulePromoteToLauncherAndMove`/`pendingPinnedSource` absent. Drag feature (promote a running task to a launcher by dragging into the pinned zone). Our drag is qt6-derived; confirm the behavior exists another way or is missing. |
| f559f521b | 2026-05-05 | fix(indicators/default): Header color set for contrast | PORT | Part of the indicator-theming cluster above; same absence. |
| cb89df82a | 2026-05-05 | fix(communicator): detect plasmoid root for P6 bridge | CHECK | `appletDefaultRootItem` bridge-attachment logic absent from our communicator QML. Verify our Latte↔applet bridge attaches correctly on Plasma 6 (indicators/abilities depend on it). |
| 74a2f9ef2 | 2026-05-05 | fix(indicators): Latte panel palette for contrast | PORT | Indicator-theming cluster; adds `panelPalette` through colorizer/MyView/LatteBridge. Absent in our port. |
| 7ce95f470 | 2026-05-05 | fix(indicator/factory): user-local packages override system | PORT | `app/indicator/factory.cpp` has no user-local-override precedence. Small, self-contained C++ fix; lets a user's own indicator package win over a system one. |
| 133043754 | 2026-05-05 | fix(tasks): keep icon visible when only audio badge shown | CHECK | No matching markers in our `task/TaskIcon.qml`. Verify the icon doesn't vanish when a task shows only its audio badge. |
| b0fc8c5f2 | 2026-05-05 | fix(communicator): avoid binding loop in appletDefaultRootItem | CHECK | Follow-up to cb89df82a; same communicator bridge our port doesn't have this form of. |
| 32fcb6886 | 2026-05-05 | fix(plasmoid): use Plasmoid.internalAction() for P6 | HAVE | Present: `main.qml:254` uses `Plasmoid.internalAction("configure")`. |
