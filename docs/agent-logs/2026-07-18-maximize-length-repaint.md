# 2026-07-18 maximize-length repaint (stale frosted band) - ledger

The bug: the panel option "maximize panel length in presence of maximized
windows" (`maximizeWhenMaximized`) grows a masked dock to full width while a
maximized window is present and shrinks it back on un-maximize. On Qt6 wayland
the just-vacated edge pixels render as a lighter frosted/semi-transparent band
at the FORMER extent - stale content the compositor keeps compositing. Caught
live on a real top dock.

## Root cause (proven, platform-forced)

Qt6's wayland backend couples `QWindow::mask()` to each frame's submitted
buffer damage: Qt restricts the damage it submits to the current mask region.
When the visible band SHRINKS, the scene graph repaints the vacated edge
transparent, but that damage falls OUTSIDE the new, smaller mask and is
dropped, so the compositor never learns those pixels changed and keeps
compositing the stale semi-transparent panel content there. Qt5/X11 shape
masks did not clip damage; this is a platform-forced Qt6 deviation with no
upstream precedent (the code and commit say so).

This is the same `QWindow::mask()`/damage coupling that the existing
`setInputMask` comment already documents for the empty-mask "whole surface
frozen at last content" case - the shrink case is its sibling.

## The fix

A pure core owns the "what region to hand `QWindow::setMask`" decision:
`app/view/inputmaskflush.h`, `Latte::ViewPart::InputMaskFlush`.

- `windowMaskFor(applied, band)`: a clear/degenerate band clears the mask; a
  first band with no prior applied mask is used as-is; otherwise the UNION of
  the applied region and the new band is kept. Growing collapses to the band on
  its own (a wider band already contains the old applied region, `united ==
  band`); a shrink stays wide (`united ==` the old, wider applied region) so the
  vacated edges stay inside the mask and their clearing damage is not clipped.
  It asserts its contract - `result.contains(applied)` - which `united()`
  satisfies by construction and a naive `return band` violates on a shrink.
- `needsSettleCollapse(applied, band)`: whether the applied mask is still wider
  than the band, i.e. the settle collapse is owed.

`Effects` (app/view/effects.cpp) routes `setInputMask` through
`applyInputMaskToWindow()`, keeps `m_appliedInputMask` (the region actually
handed to `setMask`), and arms a 100ms single-shot coalescing timer
(`m_inputMaskSettleTimer`, restarted on every band change) that, once the band
is quiet, narrows the window mask from the union back to the exact band so
steady-state hit-testing and libplasma popup anchoring read the real band.
`m_inputMask` still reports the logical band, so QML readback is unchanged.

Observability: `Effects::appliedInputMask()` and a new
`appliedInputRegionRects` array in `viewsData` report the applied window mask
so the union/collapse is queryable, not pixel-peeped (D-Bus reference +
observability docs updated; dbusreportstest pins the new key and its
empty-means-cleared convention).

## Verification

### Pure-core unit test + tripwire (SIGABRT)

`tests/units/inputmaskflushtest.cpp` (sanitized, ASan+UBSan, QT_FORCE_ASSERTS)
passes on the fix. It hand-derives every expected rect from the QRect union
geometry and pins the invariant as `shrinkKeepsUnionUntilSettle` /
`animatedShrinkNeverClipsVacatedEdges`.

Tripwire proven: reverting the core's `applied.united(band)` to a naive
`return band` (the shape both reference forks still ship) and running the
sanitized binary aborts on the FIRST shrink case:

```
QFATAL : InputMaskFlushTest::shrinkKeepsUnionNotBand() ASSERT: "result.contains(applied)"
         in file .../app/view/inputmaskflush.h, line 63
FAIL!  : InputMaskFlushTest::shrinkKeepsUnionNotBand() Received a fatal error.
Received signal 6 (SIGABRT)
```

Restored to `united()`, the binary is green again.

### Nested-vehicle integration (state + instrumentation)

Vehicle limitation found and recorded: `existsWindowMaximized` never flips in
the nested vehicle - this vehicle's kwin does not surface the plasma
window-management maximized state to Latte. A konsole cycled maximized (1464x824)
<-> normal (500x300) via KWin scripting left the dock's band unchanged at 641px,
measured. Live-writing `maxLength` to the layout file did not reload either (no
file watch), and pointer hover did not expand this config's band. So the literal
maximize-length feature is not drivable here.

The IDENTICAL band-shrink code path is the exact quantity `maximizeWhenMaximized`
overrides - `maxLength` - so I drove it through the edit-mode length ruler below
the applet extent (~54% here), where the band actually shrinks. On the
instrumented dock (temporary `qWarning` in `applyInputMaskToWindow` + the settle
lambda, since removed) each deliberate down-detent produced the union-then-collapse:

```
apply band=769x78 applied=874x78 settleArmed=true   [band shrank 874->769, applied HELD at the 874 union]
settle-collapse applied=769x78 band=769x78           [collapsed to the band ~105ms later]
apply band=641x56 applied=727x56 settleArmed=true   [727->641, applied held at the 727 union]
settle-collapse applied=641x56 band=641x56           [collapsed]
apply band=540x44 applied=641x44 settleArmed=true   [641->540, applied held at the 641 union]
settle-collapse applied=540x44 band=540x44           [collapsed]
```

The ~100ms union-hold is below D-Bus round-trip latency - rapid-sampling
`appliedInputRegionRects` right after a detent (8 samples/detent) never caught
`applied != input`, measured - so no automated D-Bus recipe can assert the
transient. The unit test is its tripwire.

Standing guard: `tests/e2e/070-maximize-length-mask.sh` drives the same
ruler-shrink and asserts per-view over D-Bus that after every shrink settles
the applied window mask has COLLAPSED back to the band (`applied == input`). A
settle that failed to fire would leave the applied mask stuck at the pre-shrink
union (`applied` wider than `input`) and fail. Passes on the clean fix; band
shrank 874 -> 769 -> 727 -> 641 -> 540 with the applied mask collapsed at
every step.

## F2 (independent review of PR #24): blast radius, and the length-axis scoping

The only external driver of the input mask is VisibilityManager.qml ->
effects.inputMask, so the union-hold governed EVERY input-mask shrink, not just
maximize-length. computeInputMask (containment/plugin/units/maskgeometry.h)
shrinks the band on three paths: (1) maxLength / maximize-length, (2) parabolic
zoom-OUT (unhover), (3) autohide/dodge HIDE (the band collapses to its reveal
strip). (1) and (2) shrink the LENGTH axis; (3) shrinks the THICKNESS axis (same
length, thinner).

Verified in the nested vehicle (autohide works there, unlike existsWindowMaximized;
same temporary instrumentation approach, plus REVEAL-TEMP logging in
setContainsMouse / setIsHidden / raiseView). setContainsMouse is driven by the
dock window's QEvent::Enter/Leave, which the compositor gates by the window mask,
and it drives raiseView - so the mask IS the reveal-trigger surface. On an
autohide HIDE the un-scoped union-hold held the FULL former band as the input
mask while the dock was hidden (measured, bottom dock):

```
apply band= QRect(363,382 874x2)  applied= QRect(363,296 874x88) settleArmed= true   [OVER-CAPTURE: hidden, holds the 88px body]
```

That is a real regression: for the settle window a hidden dock accepts pointer
input across its whole vacated body (clicks swallowed instead of falling
through; the reveal-sensitive area widened from the 2px strip to the 88px band),
and the hold provides no rendering benefit (the dock leaves on hide, nothing is
stranded where it stood). A masked dock's hidden input region MUST be exactly
its reveal strip.

ROOT-CAUSE FIX (not a downstream guard): scope the union-hold to LENGTH-axis
shrinks. windowMaskFor gained a Qt::Orientation lengthAxis (Effects::lengthAxis:
horizontal for Top/Bottom, vertical for Left/Right); it holds the union only
when the band shrinks along that axis, and applies the band directly otherwise.
Zoom-out (a length shrink that can also frost at the overshoot ends) stays held;
the autohide/dodge HIDE (thickness) no longer is. Re-verified in the vehicle:

```
apply band= QRect(363,382 874x2)  applied= QRect(363,382 874x2)  settleArmed= false   [FIXED: strip applied directly on hide]
apply band= QRect(415,306 769x78) applied= QRect(363,306 874x78) settleArmed= true    [maximize-length STILL held]
```

D-Bus at rest-hidden confirms appliedInputRegionRects == inputRegionRects == the
strip. inputmaskflushtest pins the scoping (thicknessShrinkAppliesBandDirectly,
verticalDockHoldsOnHeightShrink); 070 still passes.

The remaining sibling path is zoom-OUT (a length shrink, still held). It is a
mild extension of the pre-existing full-length-input-during-zoom workaround
(11f42978): the applied mask stays full-length for ~100ms after the zoom-out
animation settles, so a click in the vacated length-ends (beyond the settled
applet band) within that window hits the dock instead of falling through. The
dock is shown and the pointer is leaving, so this is minor; it is called out in
the desk-check below for a live eyeball.

## Desk-check owed to Bree (real session, the "no frosted band" pixel confirm)

The nested vehicle cannot exercise the real maximize-length feature (see above),
so the visual confirmation is a desk-check on the live session:

1. A masked TOP or BOTTOM dock (a Latte dock, not a plasma panel), maxLength
   below full (e.g. 60%) so it is visibly shorter than the screen.
2. Its config: "Maximize panel length in presence of maximized windows" ON
   (Behavior / or `maximizeWhenMaximized=true` in the containment's General
   group).
3. Maximize a window on that dock's screen - the dock grows to full screen
   width.
4. Un-maximize it (restore) - the dock shrinks back to its ~60% band.
5. LOOK at the just-vacated edge regions (between the shrunken dock's ends and
   the screen edges), especially against a dark wallpaper: BEFORE the fix a
   lighter frosted/semi-transparent band lingers there at the former full-width
   extent; AFTER the fix those regions are clean (the vacated pixels clear).
   The band, if present, sits within ~100ms plus animation of the un-maximize.
6. Repeat the maximize/un-maximize cycle a few times; the artifact is most
   visible right after the shrink and on a busy/bright background behind the
   vacated edges.

Query while checking: `busctl --user call org.kde.lattedock /Latte
org.kde.LatteDock viewsData` and read the view's `appliedInputRegionRects` vs
`inputRegionRects` - they agree at rest and during the grow, and the applied
one is briefly wider during the length shrink.

Two sibling live checks from the F2 review (both expected fine, worth an
eyeball):

- Autohide/dodge: with the dock in an autohide or dodge mode, hover to reveal
  then move away to hide. There should be NO flicker / spurious re-reveal right
  after it hides, and a click just above the hidden dock's reveal strip should
  reach whatever is behind (the dock must not swallow it). The scoping makes the
  hidden input region exactly the reveal strip; the vehicle confirmed the strip
  is applied directly on hide.
- Zoom-out: on a zoom-enabled dock, hover an icon (band zooms/extends) then move
  the pointer off. A click in the just-vacated zoom-overshoot area (past the
  settled applet band) within ~100ms of leaving is briefly caught by the dock
  rather than falling through. This is the one remaining held length-shrink; if
  it is ever noticeable, the zoom-out path can be excluded from the hold too.
