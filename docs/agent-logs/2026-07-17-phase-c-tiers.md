# Phase C - per-distro golden tiers (sceneprobe tier/device decoupling)

Multi-distro CI plan, Phase C1/C2. Branch `multi-distro-ci-phase-c`.
Landed 2026-07-17.

## The coupling that was broken

`tests/sceneprobe/main.cpp` keyed BOTH the golden filename and the
compare tolerance off one variable, `SCENEPROBE_DEVICE`:

    const QString refPath = base + ".expected." + device + ".png";   // filename
    CompareTolerance tol = (device == "lavapipe")                    // rigor
        ? {0, 0.0} : {2, 0.005};

That conflates two independent axes. The DEVICE is what rendered the
frame (lavapipe under CI, or an opt-in dgpu). The TIER is how tightly we
compare. Fedora and KDE neon render on the lavapipe DEVICE - so they
correctly compare the nix-blessed `.expected.lavapipe.png` goldens - but
their Mesa/LLVM rounds 5 of the 13 scenes one LSB off the nix pin, a max
per-channel Δ of 2 (B3). Because rigor was keyed on the device, the
`device == "lavapipe"` branch forced them to the bit-exact `{0,0}` tier
and failed them, with no way to say "same device, looser compare".

## The design

Split rigor onto its own axis, `SCENEPROBE_TIER`, an `enum class
GoldenTier { BitExact, Tolerance }` that lives with `CompareTolerance`
in the imagecompare module (`tests/sceneprobe/imagecompare.{h,cpp}`):

- `parseGoldenTier(QByteArray)` parses the env once. Empty/unset ->
  `BitExact` so the NixOS/dev merge gate is byte-identical when nothing
  sets it. Unknown value -> `std::nullopt` so the probe refuses it
  LOUDLY (`FATAL` + exit 2) at the boundary in `main()` rather than
  silently falling through to a wrong rigor (a typo'd tier must not mask
  a regression by defaulting bit-exact, nor hide one by defaulting
  tolerance). Case-sensitive: the tier is a fixed vocabulary set by the
  container ENV / gate script, not free text.
- `toleranceForTier(GoldenTier)` switch-maps the tier to its
  `CompareTolerance` (exhaustive over the enum, `Q_UNREACHABLE` after).
- `main()` parses the tier once at startup and selects the tolerance
  from it. The DEVICE still keys the golden FILENAME (every matrix
  distro renders lavapipe, all compare `.expected.lavapipe.png`) and
  still owns the missing-golden rule (hard-fail on lavapipe, loud skip
  on opt-in dgpu). The per-scene `probeTolerance` QML override still
  layers on top.
- `scripts/sceneprobe-gate.sh` forwards `SCENEPROBE_TIER` through to the
  probe (default bitexact when unset), the same way it already forwards
  `SCENEPROBE_DEVICE`.
- Each `ci/containers/Containerfile.<distro>` declares its tier in its
  ENV block: Fedora + neon = `tolerance`; Arch, Debian, openSUSE, Void,
  Gentoo = `bitexact` (explicit, also the probe default, so the tier is
  a visible per-distro property). Each bit-exact leg's comment notes the
  bit-exact match is a rolling-Mesa accident and the tier is the one
  knob to flip to `tolerance` if a future Mesa/LLVM bump introduces a
  delta - no goldens or device change needed.

Why not per-distro goldens for Fedora/neon: the graduated-rigor model
puts rolling/non-nix distros in the "invariant + bounded tolerance"
tier, which compares the SAME nix goldens with a delta rather than
blessing per-distro pixel sets that rot. The bless-frozen-stable tier
(a distro's own `.expected.<distro>.png` for a pinned tag) is NOT built
here because the matrix did not need it; the device-keyed golden naming
already supports it (set `SCENEPROBE_DEVICE=<distro>` to bless/compare
`.expected.<distro>.png`) if a future C2 decides a pinned Fedora/neon
tag should carry a bit-exact golden. No unused machinery was added.

## The tolerance value: {2, 0.005}, and why

`compareImages` counts a pixel as differing only when its max channel
delta strictly EXCEEDS `perChannelDelta`, and matches when the differing
fraction is `<= maxExceedFraction`. Fedora and neon show max Δ=2 with NO
pixel exceeding Δ2, so `perChannelDelta = 2` filters every differing
pixel and the measured exceed fraction is 0% on all 13 scenes on both
distros. The 0.5% budget is margin, not need. This is the exact value
the compare already used for non-lavapipe devices before the split; the
tier now owns it instead of the device, so no new constant was
introduced.

## Verification (the definition of done)

All three run 2026-07-17 on this host (podman, shared CPU).

1. NixOS merge gate UNCHANGED (P0). `scripts/sceneprobe-gate.sh` on the
   branch head, SCENEPROBE_TIER unset -> default bitexact {0,0}:
   **13/13 bit-exact PASS**, self-test ok. Byte-identical to before the
   split (the default path is the same {0,0} tolerance the
   `device==lavapipe` branch produced). The full `scripts/gate-all.sh`
   stamp is green on the branch head.

2. Tolerance tier passes Fedora AND neon in-container. Images rebuilt
   with the new tier ENV baked in (`SCENEPROBE_TIER=tolerance` confirmed
   in-env at runtime), port rebuilt in-container against the changed
   source, then `scripts/sceneprobe-gate.sh`:
   - Fedora (fedora:43, Mesa LLVM 21.1.8): **13/13 PASS** at tolerance.
   - neon (plasma:user, Mesa LLVM 20): **13/13 PASS** at tolerance.
   Load-bearing cross-check: the SAME Fedora build+goldens at
   `SCENEPROBE_TIER=bitexact` **FAILS, exit 1, exactly 5 scenes**
   (applet_colorizer/indicator_glow/multieffect_degenerate/shadoweditem
   at Δ=1, multieffect_blur 93.3% px at Δ=2) - matching B3 exactly. Same
   distro, same device, same goldens; only the tier differs and it flips
   the verdict, proving the tier is what does the work, not a golden or
   device change.

3. A bit-exact distro still gates bit-exact. Arch (bitexact tier ENV,
   `SCENEPROBE_TIER=bitexact` confirmed in-env), in-container build +
   gate: **13/13 bit-exact PASS**, exit 0. The tier change did not
   loosen the bit-exact legs.

4. Unit tests: `sceneprobe_imagecompare` 27/27 (Goree's 21 + 6 new
   GoldenTier cases): unset defaults BitExact (the merge-gate-critical
   contract), explicit bitexact/tolerance, unknown/wrong-case refused as
   nullopt, BitExact -> {0,0}, Tolerance -> {2,budget} accepting a Δ=2
   fill and rejecting Δ=3 through the real `compareImages`. Probe
   boundary: `SCENEPROBE_TIER=bogus` -> FATAL + exit 2 before any Vulkan
   setup.

## Available extension, not built now

A pinned-tag stable distro (Fedora N, neon tag) could carry a
bless-frozen bit-exact golden `.expected.<distro>.png`, re-blessed when
the base image bumps. The device-keyed golden naming already supports it
(`SCENEPROBE_DEVICE=<distro>` + `--bless`); the tier axis is orthogonal.
Not wired because the current matrix put Fedora/neon in the tolerance
tier instead. If a rolling bit-exact leg (Arch/Debian/openSUSE/Void/
Gentoo) later rots to a delta, flip its Containerfile `SCENEPROBE_TIER`
to `tolerance` - that is the whole change.
