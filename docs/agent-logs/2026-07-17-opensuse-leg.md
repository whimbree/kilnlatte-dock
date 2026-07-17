# openSUSE Tumbleweed leg - multi-distro CI matrix (Phase A/B)

Worktree subagent leg, 2026-07-17. Brought up the openSUSE Tumbleweed
build+gate environment (`ci/containers/Containerfile.opensuse`), a clean
in-container cmake build, and the headless sceneprobe render, replicating
the proven Arch leg. Scope: build + sceneprobe (B3). The e2e gate wiring
(B2) is a parallel agent's job and is not touched here.

## Floor versions observed (Tumbleweed rolling, image built 2026-07-17)

Well past the Plasma>=6.5 / Qt>=6.6 / KF6>=6.5 floor:

- Qt 6.11.1
- KF6 6.28.0
- Plasma + kwin 6.7.3
- Mesa (lavapipe) 26.1.4, Vulkan loader 1.4.350, validation layers 1.4.350

## Build result

`ci/build-and-gate.sh build` -> clean, 565/565 targets (same target count
as the Arch leg), against Tumbleweed's Qt 6.11.1 / KF6 6.28.0 / Plasma
6.7.3.

`ci/build-and-gate.sh test` -> 77/81 ctest pass. The 4 failures
(qmlcompilegate, qmlinteraction, qmllintgate, qmlcontracts) are all the
harness-env QML-gate class the Arch leg already deferred to Phase B, plus
one Tumbleweed-specific trap under it (see Traps): the Qt6 QML tooling is
not in PATH. No SOURCE change was needed and none was made - the two
portability gaps hit were both image dep-name/layout gaps, fixed in the
Containerfile.

## Sceneprobe render (B3)

`scripts/sceneprobe-gate.sh` in-container -> self-test ok, all 13 real
scenes PASS. Bit-exact against the nix-blessed lavapipe goldens (the
`SCENEPROBE_DEVICE=lavapipe` `{0,0}` tier), same as Arch: Tumbleweed's
Mesa 26.1.4 lavapipe matches nix Mesa for these text-free scenes, so no
tolerance tier was needed at this Mesa version. Recorded, not relied on -
Phase C still owns the per-distro rolling-drift tier.

## Dep-name resolution (Arch -> Tumbleweed)

Resolved by `zypper search`/`info` prototyping in the base image. All KF6
frameworks are `kf6-<name>-devel`. Notable renames:

- extra-cmake-modules -> `kf6-extra-cmake-modules`
- qt6-base/declarative/wayland -> `qt6-base-devel qt6-declarative-devel qt6-wayland-devel`
- qt6-5compat -> `qt6-qt5compat-devel`
- Qt private headers (sceneprobe links Qt6::GuiPrivate for qrhi.h) ->
  `qt6-base-private-devel` (Arch bundles these in qt6-base; Tumbleweed
  splits them out - this was the first build blocker)
- qt6-shadertools/tools/svg -> `qt6-shadertools-devel qt6-tools-devel qt6-svg-devel`
- libplasma -> `libplasma6-devel`
- plasma-activities / -stats -> `plasma6-activities-devel plasma6-activities-stats-devel`
- plasma-workspace -> `plasma6-workspace-devel`
- kwayland -> `kwayland6-devel`
- plasma5support -> `plasma5support6-devel`
- kpipewire -> `kpipewire6-devel`
- libksysguard -> `libksysguard6-devel`
- qqc2-desktop-style (runtime QML style) -> `kf6-qqc2-desktop-style`
- plasma-wayland-protocols -> `plasma-wayland-protocols` (no -devel suffix)
- wayland / wayland-protocols -> `wayland-devel wayland-protocols-devel`
- layer-shell-qt -> `layer-shell-qt6-devel`
- kwin (provides kwin_wayland) -> `kwin6`
- vulkan loader/headers/validation -> `libvulkan1 vulkan-headers vulkan-devel vulkan-validationlayers`
- lavapipe ICD -> `libvulkan_lvp`
- noto-fonts -> `google-noto-sans-fonts`
- dbus -> `dbus-1`
- libcap (setcap) -> `libcap-progs`
- python3 -> `python313-base` (no bare `python3` package; e2e/B2 dep)
- ImageMagick -> `ImageMagick` (e2e screenshot dep for B2)
- build tools: `cmake ninja git jq gettext-tools pkgconf pkgconf-pkg-config gcc-c++ make rsync perl`

## Resolved runtime paths (the ENV block)

- lavapipe ICD: `/usr/share/vulkan/icd.d/lvp_icd.x86_64.json` (arch-suffixed
  name - Arch ships plain `lvp_icd.json`)
- validation layers: `/usr/share/vulkan/explicit_layer.d`
- framework QML tree: `/usr/lib64/qt6/qml` (lib64 multilib - Arch/nix use lib)
- KDE_INSTALL_QMLDIR (build/latte-qmldir.txt) came out `lib64/qt6/qml`, so
  the 00400f16c / 18aac31b0 fixes carry the leg with no source change.

## Traps

1. `qt6-base-private-devel` split. The sceneprobe target's
   `find_package(Qt6 REQUIRED COMPONENTS GuiPrivate)` aborted configure
   until this package was added. Tumbleweed splits Qt private headers into
   a separate -private-devel package; Arch bundles them in qt6-base. Not a
   source defect - a distro dep-split.

2. kwin_wayland cap_sys_nice=ep. Identical trap to Arch (79a8008f0):
   /usr/bin/kwin_wayland ships with the effective CAP_SYS_NICE bit and
   podman's default cap set excludes it, so execve fails EPERM and the
   nested compositor never comes up. `setcap -r /usr/bin/kwin_wayland`
   (libcap-progs) in the image strips it.

3. Qt6 QML host tools not in PATH. `qmllint`, `qmlcachegen` and
   `qmlimportscanner` live under `/usr/lib64/qt6/bin` and `/usr/libexec/qt6`
   on Tumbleweed; only a versioned `/usr/bin/qmllint6` is on PATH, and
   `qmlcachegen`/`qmlimportscanner` are not on PATH at all. This is why the
   4 QML-gate ctests fail under the plain `test` stage. It does NOT affect
   the sceneprobe gate (it never invokes qmllint). Flagged for the B2 gate
   wiring: the QML gate scripts discover these tools by bare name and would
   need a Qt6-bindir-aware lookup (qtpaths6 --query QT_HOST_BINS /
   QT_INSTALL_LIBEXECS) to run green on Tumbleweed. Left to B2/the gate
   stage owner - not fixed here (out of scope, and build-and-gate.sh /
   the gate wiring is B2-owned).

## F2 portability notes (the future .rpm spec must build on BOTH Fedora AND Tumbleweed)

Package-name and macro divergences noticed that the single .spec will have
to bridge (Tumbleweed side observed here; Fedora side from general Fedora
naming, to be confirmed on that leg):

- KF6 frameworks: Tumbleweed `kf6-<name>-devel`; Fedora `kf6-<name>-devel`
  too, so this axis mostly agrees - but ECM is `kf6-extra-cmake-modules` on
  Tumbleweed vs `extra-cmake-modules` on Fedora.
- Qt6 private headers: Tumbleweed `qt6-base-private-devel`; Fedora
  `qt6-qtbase-private-devel` (Fedora prefixes the Qt module `qt`, e.g.
  qt6-qtbase-devel, qt6-qtdeclarative-devel) - a real BuildRequires
  divergence for the spec.
- Qt5Compat shim: Tumbleweed `qt6-qt5compat-devel`; Fedora
  `qt6-qt5compat-devel` (agrees).
- libplasma: Tumbleweed `libplasma6-devel`; Fedora `plasma-libs` /
  `libplasma-devel` naming differs - confirm on the Fedora leg.
- kwin: Tumbleweed `kwin6`; Fedora `kwin` (unversioned name).
- %cmake macros: Tumbleweed's OBS `%cmake_kf6` / `%cmake` vs Fedora's
  `%cmake` + `%cmake_build` - the spec's build section needs macro
  conditionals or a lowest-common-denominator explicit cmake invocation.
- lavapipe/vulkan naming (if the render gate ever runs from an installed
  package): Tumbleweed `libvulkan_lvp`; Fedora `mesa-vulkan-drivers`
  bundles lavapipe - not a spec BuildRequires but a CI-image note.

## Reproduce

From the repo root (or the worktree checkout):

    podman build -t latte-opensuse -f ci/containers/Containerfile.opensuse .
    SRC=$PWD BUILDDIR=$(mktemp -d)
    podman run --rm -v "$SRC":/src:ro -v "$BUILDDIR":/build latte-opensuse \
        bash /src/ci/build-and-gate.sh build      # 565/565
    podman run --rm -v "$SRC":/src:ro -v "$BUILDDIR":/build latte-opensuse \
        bash /src/ci/build-and-gate.sh test        # 77/81 (4 QML-gate harness-env)
    podman run --rm -v "$SRC":/src:ro -v "$BUILDDIR":/build latte-opensuse \
        bash -c 'BUILD=/build bash /src/scripts/sceneprobe-gate.sh'   # 13/13 PASS
