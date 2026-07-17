# 2026-07-16: sceneprobe follow-up scenes (the four owed by the P1 tick)

Executing the follow-up named in
docs/agent-logs/2026-07-16-sceneprobe-transplant.md ("Follow-ups owed")
and the adoption plan's P1 scene list: parabolic_zoom, the colorizer
ColorOverlay stack, the forced-monochromatic icon path, and indicator
glow. Each scene mirrors a named production call site in OUR tree (not
the fork's versions), declares probeExpect where a meaningful invariant
exists, and gets its golden blessed only after a two-run byte-identical
determinism check inside the nix environment.

Branch: worktree-agent-a101a650b6784ba6e (worktree merge will rebase
the hashes listed at the bottom).

## Font decision: text-free, recorded reasoning

The fork's parabolic_zoom renders Text with no font family pinned - a
latent cross-machine flake the adoption plan flagged. The alternative
was shipping/pinning a store-path font. Decision: text-free redesign,
for three reasons:

1. Fidelity: the production parabolic content is icons
   (Kirigami.Icon / the applet's contentItem), not text. The fork's
   Text "A" was incidental scene filler, so text adds no mirroring
   value at this site.
2. Precedent: the transplant already replaced Text with shapes in all
   six multieffect scenes and badgeeffect for exactly this reason;
   staying text-free keeps the whole scene set on one determinism
   story.
3. A pinned font file alone does not pin rendering: fontconfig config,
   hinting and antialiasing settings feed the rasterizer too, so "ship
   a font" actually means "pin the whole fontconfig surface". The
   text-free redesign deletes that dependency instead of managing it.

## Per-scene design notes

### parabolic_zoom.qml

Mirrors declarativeimports/abilities/items/basicitem/ParabolicItem.qml:
the zoom is SIZE-driven, not transform-driven - _contentItemContainer's
width follows newTempSize (iconSize * zoom) while anchored to the
screen edge, and zoom changes animate through Behavior on zoom
(NumberAnimation, Easing.OutCubic). The scene reproduces that shape:
a bottom-anchored container whose width/height bind to
iconSize * zoom, with zoom animated 1.0 -> 1.6 under the fixed-step
clock using the NumberAnimation-on-property form multieffect_degenerate
already proved deterministic. The animation duration (48ms) completes
before the last rendered frame (t=80ms), so the final readback is at
zoom = 1.6 exactly - the expectations do not depend on easing
interpolation.

probeExpect: an icon-colored pixel inside the zoomed box but OUTSIDE
the unzoomed box (fails if the zoom never applies or the animation
machinery stalls), the white center detail (fails if the container
scales around the wrong anchor), background at a corner and at a point
just outside the zoomed box (fails if the container overgrows).

### applet_colorizer.qml

Mirrors containment/package/contents/ui/applet/colorizer/Applet.qml
(the 1f835402 fix structure): Qt5Compat.GraphicalEffects.ColorOverlay
sampling the applet wrapper, with the item shadow as the ColorOverlay's
layer.effect (LatteComponents.ShadowedItem) rather than a sibling.
The scene exists to catch the "colorizing is a silent no-op" family:
dark content (like dark clock text) colorized towards a light
applyColor. Correct ColorOverlay semantics paint the applyColor FLAT
through the alpha; the MultiEffect.colorization substitution both
reference forks shipped multiplies by the source's gray level and
re-outputs dark pixels.

probeExpect: the content pixel reads the light applyColor with a
tolerance sized to reject the dark no-op output; a shadow-colored pixel
outside the content shape (asserts the layer-effect shadow actually
samples and paints); background where the wrapper is transparent.

### forced_monochromatic.qml

Mirrors the 1932db32 sites: ParabolicItem's side-painting Loader
(anchors.fill the content, ColorOverlay painting the palette textColor
through the icon alpha) with TaskIcon.qml's provider-stability rider -
the source item's layer held ON permanently while the overlay exists
(taskIconItem's layer.enabled gate), so the scene's ColorOverlay
samples a LAYERED source exactly like the production arrangement.
Same silent-no-op family as the colorizer: dark icon pixels forced to
a light textColor must come out light and flat.

probeExpect: two glyph-bar pixels of different source darkness both
read the same flat textColor (flatness across different source
luminances is precisely what colorization-vs-overlay distinguishes);
the transparent gap between bars reads background (alpha respected).

### indicator_glow.qml

Mirrors indicators/default/package/ui/main.qml firstPoint - the default
indicator's active-task dot as it actually instantiates
LatteComponents.GlowPoint: line-style active width, showGlow (the
glowApplyTo=All branch), glow3D with showBorder: glow3D, roundCorners,
location BottomEdge, contrastColor standing in for the indicator
shadowColor. GlowPoint is the QtQuick.Shapes port (RadialGradient/
LinearGradient ShapePaths replacing the Qt5 GraphicalEffects
gradients), so this scene pins that rendering path.

probeExpect: the line center reads the active basicColor (through the
glow3D shadow blend, measured), a point in the glow halo above the
line reads the measured gradient blend (fails if the Shapes gradients
stop painting - the glow silently vanishing family), background at a
far corner.

## Direction changes folded in mid-task (my direction relayed through
## the coordinator, 2026-07-16)

1. dgpu device mode restored as a DOCUMENTED optional extra. The
   transplant stripped the fork's dgpu env block; the harness must now
   also WORK with a GPU but never REQUIRE one - it runs in CI (plain
   VM, lavapipe), on my desktop (real GPU), and in a microvm
   (lavapipe). This supersedes the adoption plan's "the dgpu golden
   tier ... harmless as an undocumented local extra" line on the
   documented-vs-undocumented point only; the VM-only constraint still
   binds everything CI depends on. Implementation: the device dispatch
   stays the single case statement in tests/sceneprobe/run_in_kwin.sh -
   lavapipe (default, pinned ICD + LP_NUM_THREADS=0) or dgpu (opt-in,
   loader enumerates the host's ICDs, MESA_VK_DEVICE_SELECT left to
   the caller - the fork hardcoded its own card's 1002:7550, a
   hardware pin that does not belong in the repo). The validation
   layer comes from the flake pin in both modes. Golden sets stay
   per-device and independent; the probe's missing-golden behavior is
   now tier-aware: hard failure on lavapipe (a deleted golden must
   never silently gut the compare), a loud "no goldens blessed for
   this device" notice on dgpu with all non-golden gates still
   verdicting, so a desktop GPU run is useful without a blessing
   ceremony. scripts/sceneprobe-gate.sh keeps gating on lavapipe only,
   and no dgpu goldens are blessed here. Nothing outside the one
   dispatch point hardcodes a device (the scenes are device-agnostic;
   main.cpp's two device checks are the tolerance tier and the
   missing-golden tier, both keyed on the golden-set name).

2. Negative confidence for the scene set: CaptSilver's harness and
   scenes are the floor, not the ceiling. Each of the four scenes gets
   its target defect family INJECTED (same spirit as the gate
   self-test) to prove the scene actually fails on it, with the
   injection results recorded below. The other quality bars this
   direction names were already load-bearing in the designs above:
   probeExpect invariants on every scene, headers naming the exact
   production construct, deterministic-by-construction content.

## Negative-confidence injections

Each injection is a scratchpad copy of the final scene with exactly the
defect family the scene exists to catch, run through a gate-equivalent
environment; the required outcome is exit 1 with the failure reported
by probeExpect (the injected scenes have no goldens, so only the
probeExpect line proves the scene's own assertions catch the break):

Results - every scene fails on its own family, at the exact pixel its
design nominated:

- parabolic_zoom, injected break: the zoom animation stalled
  (running: false, zoom stuck at 1.0). exit 1,
  "pixel (128,130) #303030 != expected #ff8c00" - the
  inside-zoomed-outside-unzoomed point reads background.
- applet_colorizer, injected break: the effect swapped back to
  MultiEffect.colorization (both forks' substitution, the 1f835402
  family). exit 1, "pixel (128,128) #232323 != expected #eff0f1" -
  the dark no-op output, reproduced verbatim.
- forced_monochromatic, injected break: same colorization swap (the
  1932db32 family). exit 1, "pixel (128,92) #343434 != expected
  #fcfcfc" - the luminance-preserving tint leaves the dark bar dark.
- indicator_glow, injected break: showGlow false (the glow silently
  vanished). exit 1, "pixel (128,190) #181818 != expected #2e7397" -
  the halo point reads background.

The two colorization injections output exactly the gray-level-tint
values the commit bodies describe, which is as direct a reproduction
of the defect family as a 256x256 scene can give.

## dgpu verification (on this machine's real GPU)

- SCENEPROBE_DEVICE=dgpu under the nested kwin picked
  "AMD Radeon RX 5700 XT (RADV NAVI10)" with no ICD forced.
- The missing-golden notice prints loudly per scene
  ("no goldens blessed for device 'dgpu' - golden compare skipped,
  all other gates still apply") and the run exits 0 when the
  non-golden gates pass.
- ALL 13 scenes ran clean on RADV: shader gate, validation gate,
  blank floor and every probeExpect held on real hardware - the
  measured lavapipe expectations are genuinely cross-device
  invariants at their declared tolerances, not lavapipe trivia.
- SCENEPROBE_DEVICE=bogus refused loudly, exit 2.
- Full lavapipe gate re-run after the harness change: self-test ok,
  13/13 PASS, exit 0. No dgpu goldens blessed, per the direction.

## Also fixed in passing

multieffect_colorize.qml's header claimed TaskIcon badges and
ParabolicItem's monochromizer use MultiEffect.colorization - stale
since 1932db32 moved both sites to Qt5Compat ColorOverlay (the comment
predates that fix's merge into this line of work). Reworded: the scene
pins the MultiEffect.colorization shader variant itself; the
production monochromize sites are ColorOverlay and now have their own
scene (forced_monochromatic.qml).

## Execution record

- Fresh worktree build: configure + full build rc=0 before any scene
  ran (the probe binary and staging come from this tree's own build).
- First gate run: self-test ok, all 9 existing scenes PASS, the four
  new scenes fail ONLY on the missing reference - three of four passed
  their provisional probeExpect on the first render; applet_colorizer's
  shadow point read #542828 (my placeholder had borrowed the
  shadoweditem scene's stronger value).
- probeExpect values then pinned to MEASURED pixels (magick hex reads
  on the actual PNGs, pinned Mesa 26.1.2 / Qt 6.11): applet_colorizer
  content #eff0f1 EXACT (flat colorize confirmed), shadow #542828 (tol
  0.10 rejects the missing-shadow background read, red delta 36);
  indicator_glow line center #54aedd (basicColor through the glow3D
  blend), halo #2e7397 (a vanished glow reads #181818, blue delta 127);
  parabolic_zoom and forced_monochromatic came out constructed-exact
  (#ff8c00/#ffffff and #fcfcfc flat on both bars), so their declared
  values needed no adjustment.
- Visual inspection of all four actuals before blessing: the zoomed
  icon bottom-anchored at the final size, the dark bar colorized flat
  light with the red layer-effect shadow rim, three bars of differing
  darkness all one flat light color with clean gaps, the blue glow
  line with its gradient halo. indicator_glow's rectangular gradient
  extents are GlowPoint's real current rendering (the Shapes port's
  look), which is exactly what the scene pins.

## Determinism check

Two full gate runs over the final scene files, all four actual PNGs
byte-identical across runs (cmp), and the blessed goldens match those
determinism-run bytes exactly. NO scene needs a probeTolerance: all
four gate at the strict lavapipe {0,0} tier, like the transplant set.
The --bless flow also re-copied the nine existing goldens and every
one came back byte-identical to its committed file, reconfirming
cross-run determinism for the whole set.

## Gate results (final, after the dgpu harness change)

- build-check --fresh: both WITH_X11 variants from empty build dirs,
  full ctest 54/54 passed, coverage-ratchet OK (54 ctest entries, 28
  unit headers paired), build-check: OK.
- qmllint-gate: OK (233 files, 155 finding files, baseline matched).
- scripts/sceneprobe-gate.sh with the from-scratch probe binary
  against the committed goldens: self-test ok (good passes, bad
  fails, blank fails), 13/13 scenes PASS, exit 0 - the goldens
  survive a full rebuild, not just back-to-back runs. (The same gate
  also ran green twice earlier: right after blessing, and right after
  the dgpu harness change.)

## Commits

The worktree merge will rebase these hashes:

- a7c82ff75 docs: start the sceneprobe follow-up ledger - font
  decision, scene designs
- ff659005a test: the four sceneprobe scenes owed by the P1 follow-up
  list
- 7095553e2 test: bless the four follow-up scene goldens
- a553b750e test: opt-in dgpu device mode for the sceneprobe harness
- (this ledger-update docs commit closes the set)
