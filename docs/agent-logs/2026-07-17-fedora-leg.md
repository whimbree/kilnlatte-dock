# Fedora leg of the multi-distro CI matrix (Phase A/B)

Branch `multi-distro-ci-phase-a-fedora`. Replicates the proven Arch
build+render leg on Fedora: `ci/containers/Containerfile.fedora`, a clean
in-container cmake build, and the headless sceneprobe render proven
in-container. B2 (the e2e gate-stage wiring in `ci/build-and-gate.sh`) is
owned by a parallel agent and is deliberately out of scope here.

## Base tag and floor check

Base: `registry.fedoraproject.org/fedora:43` (pinned). Floor from
CMakeLists.txt is Qt >= 6.6.0, KF6 >= 6.5.0, libplasma >= 6.5.0,
PlasmaWaylandProtocols >= 1.6. Observed in-container (dnf on the updates
repo, and rpm -q after install), 2026-07-17:

    libplasma          6.7.2    (>= 6.5.0 floor: PASS)
    plasma-workspace   6.7.2     (LibTaskManager / NotificationManager / KWayland)
    plasma-activities  6.7.2
    layer-shell-qt     6.7.2
    kf6-kcoreaddons    6.28.0   (>= 6.5.0 floor: PASS)
    qt6-qtbase         6.10.3   (>= 6.6.0 floor: PASS)
    kwin               6.7.2
    cmake              3.31.11
    gcc                15.2.1

fedora:42 ships Plasma 6.3.x, below the 6.5 libplasma floor, so 43 is the
earliest Fedora stable that qualifies. Do NOT drop the tag to 42.
Deliberately did NOT copy latte-dock-ng's fedora:44 / USE_MIRRORS / USTC
mirror lines - 43 is current stable and meets the floor with the default
mirrors.

## Dep-name resolution (Fedora vs the Arch/ng starting set)

Starting point was latte-dock-ng's `docker/Dockerfile.fedora` base set
plus our superset and the render-gate tier. Resolved by `dnf repoquery`
on fedora:43. Names that DIFFER from the ng/Arch expectation:

- `kf6-plasma-devel`        -> `libplasma-devel`         (Fedora renamed the libplasma devel package)
- `qqc2-desktop-style`      -> `kf6-qqc2-desktop-style`
- `kf6-kpipewire-devel`     -> `kpipewire-devel`         (no kf6- prefix)
- `kf6-plasma5support-devel`-> `plasma5support-devel`    (no kf6- prefix)
- kwin_wayland binary       -> `kwin`                    (the `kwin` package owns /usr/bin/kwin_wayland; there is no kwin-wayland package)
- lavapipe ICD              -> `mesa-vulkan-drivers`     (ships /usr/share/vulkan/icd.d/lvp_icd.x86_64.json)
- Vulkan loader             -> `vulkan-loader`
- fonts                     -> `google-noto-sans-fonts`

Names that matched the ng set (kept): cmake extra-cmake-modules
ninja-build make gcc-c++ gettext git pkgconf-pkg-config;
qt6-qtbase-devel qt6-qtdeclarative-devel qt6-qtwayland-devel
qt6-qt5compat-devel qt6-qtshadertools-devel qt6-qttools-devel;
plasma-activities-devel plasma-activities-stats-devel
plasma-workspace-devel kwayland-devel; the kf6-*-devel core set
(kconfig kcoreaddons kguiaddons kdbusaddons kdeclarative kitemmodels
kxmlgui kiconthemes kio ki18n knotifications knewstuff karchive
kglobalaccel kcrash kwindowsystem kpackage ksvg kcmutils kirigami solid
sonnet ktextwidgets kidletime kdoctools); plasma-pa libksysguard-devel;
plasma-wayland-protocols-devel wayland-devel wayland-protocols-devel
layer-shell-qt-devel; vulkan-headers vulkan-validation-layers; dbus
dbus-daemon libcap rsync perl jq.

## Portability findings (Fedora packaging splits, NOT source defects)

Two build blockers, both Fedora packaging splits that nixpkgs and Arch
bundle into the base compiler / qt6-base packages. Neither is a source
defect - no `.cpp`/`CMakeLists.txt` change was needed - so each is a
pure dep-name (missing-package) resolution, added to the Containerfile:

1. **Qt6::GuiPrivate** - `tests/sceneprobe/CMakeLists.txt:13`
   `find_package(Qt6 REQUIRED COMPONENTS GuiPrivate)` (rhi/qrhi.h) aborts
   configure FATAL: "Failed to find required Qt component GuiPrivate ...
   Qt6GuiPrivateConfig.cmake does NOT exist". Fedora splits the Qt private
   headers into `qt6-qtbase-private-devel` (Arch/nix bundle them in
   qt6-base). Added that package; configure completes.

2. **libasan/libubsan** - the sanitized unit-test targets
   (latte_add_unit_test, the step-2.5 law) link with
   `-fsanitize=address,undefined`; the link failed
   "cannot find /usr/lib64/libasan.so.8.0.0". Fedora's `gcc-c++` does NOT
   pull the sanitizer runtimes - they ship as separate `libasan`/`libubsan`
   packages (Arch/nix bundle them with gcc). Added both; all 565 targets
   link.

These are the Fedora analogues of the four already-landed nix-isms - same
"a path/package the pinned toolchain bundles, unbundled elsewhere" class -
but they are missing BUILD DEPS, resolved in the image, not source bugs,
so no fix commit against the tree was warranted (unlike 00400f16c /
18aac31b0 which were hardcoded nix path spellings in portable tooling).

## Build result

Clean cmake build in the Fedora container, RelWithDebInfo + BUILD_TESTING=ON:
**565/565 targets** (identical target count to the Arch leg) against
Qt 6.10.3 / KF6 6.28.0 / libplasma 6.7.2.

ctest (offscreen suite): **78/82 pass**. The 4 failures are all the QML
SCRIPT-GATE ctests (qmlcompilegate, qmlinteraction, qmllintgate,
qmlcontracts) - harness-env, not port/build defects, the same class Arch
filed under Phase B. Root cause on Fedora: `qmltestrunner: command not
found`. The tools DO exist (qt6-qtdeclarative-devel is installed) but
Fedora installs the Qt6 dev tools under `/usr/lib64/qt6/bin`
(qmltestrunner, qmllint, qmlcachegen), which is NOT on the default PATH.
This is a B2 note: the gate stage needs `/usr/lib64/qt6/bin` on PATH.
(Fedora's 78/82 beats Arch's 74/82 because this image sets
LATTE_QML_MODULE_PATH in its ENV, so the QML-loading UNIT tests -
shortcutshost, layoutmanagerparking, representationswitch - resolve their
framework modules and pass; on Arch those failed for lack of the env.)

## Sceneprobe render result (B3-fedora)

All 13 scenes RENDER (non-blank, correct regions/colors, no crash) through
nested kwin_wayland on lavapipe in the container. Render device:
`llvmpipe (LLVM 21.1.8, 256 bits)`.

NOT bit-exact against the nix-blessed lavapipe goldens - this is the
EXPECTED Fedora outcome and the reason the plan's graduated-rigor model
exists. Fedora 43 ships Mesa on **LLVM 21.1.8**, where Arch (llvmpipe
22.1.8) happened to match nix Mesa bit-for-bit; the different LLVM version
lowers the shaders with 1-LSB rounding differences. Per-scene:

    PASS (bit-exact, 8):  badgeeffect, forced_monochromatic,
                          multieffect_brightcontrast, multieffect_colorize,
                          multieffect_desaturate, multieffect_mask,
                          multieffect_passthrough, parabolic_zoom
    DIFFER (render OK, 5): applet_colorizer      167 px (0.25%)  max Δ=1
                           indicator_glow        834 px (1.27%)  max Δ=1
                           multieffect_blur    61146 px (93.30%) max Δ=2
                           multieffect_degenerate   8 px (0.01%) max Δ=1
                           shadoweditem          64 px (0.10%)  max Δ=1

Max pixel delta across ALL diffs is **2** (a single LSB in one channel,
e.g. expected #ff153b24 got #ff143b24). multieffect_blur differs on 93% of
pixels but still only by Δ=2: a blur spreads the 1-LSB rounding across the
whole gradient, so almost every pixel is off-by-one while none is visibly
wrong. `checkInvariants` (structural: renders, non-blank, opaque fraction,
expected color regions) passes for every scene.

**Characterization: Fedora is a TOLERANCE-tier distro (Phase C), not
bit-exact.** A `CompareTolerance{delta=2, budget>=0.95}` passes all 13
(delta covers the LSB rounding; the high budget is needed only for the
blur scene's pixel-differ fraction). The pinned fedora:43 tag COULD later
carry a bless-frozen per-distro bit-exact golden (`*.expected.fedora.png`,
tier 2) valid for this frozen base, re-blessed on tag bumps - both are
valid; setting the actual tolerance/blessing is Phase C (C1/C2), not this
leg. sceneprobe-gate.sh exiting 1 here is CORRECT: Fedora simply is not a
bit-exact tier, and the gate is hardcoded to the lavapipe bit-exact
device.

## Reproduce (exact podman commands)

Build the deps image (heavy: full Fedora Qt/KF6/Plasma/Mesa pull):

    podman build -t latte-ci-fedora -f ci/containers/Containerfile.fedora .

Clean build of the port (source read-only at /src, out-of-source /build;
JOBS capped to be a good neighbor under concurrent agent load):

    podman run --rm -e JOBS=6 -v "$PWD":/src:ro latte-ci-fedora \
        bash /src/ci/build-and-gate.sh build

Build + offscreen ctest:

    podman run --rm -e JOBS=6 -v "$PWD":/src:ro latte-ci-fedora \
        bash /src/ci/build-and-gate.sh test

Build + sceneprobe render gate (needs the nested compositor; use a
persistent build volume to avoid rebuilding between probe runs). BUILD is
pointed at the writable /build because sceneprobe-gate.sh defaults to
$repo/build which is the read-only mount:

    podman volume create latte-fedora-build
    podman run --rm -e JOBS=6 -v "$PWD":/src:ro -v latte-fedora-build:/build \
        latte-ci-fedora bash /src/ci/build-and-gate.sh build
    podman run --rm -v "$PWD":/src:ro -v latte-fedora-build:/build \
        latte-ci-fedora bash -c 'BUILD=/build bash /src/scripts/sceneprobe-gate.sh'

## Traps / notes for the next leg

- sceneprobe-gate.sh and lib-qml-env.sh compute `repo` from the script's
  own dirname (= /src, read-only). `build` defaults to `$repo/build`,
  which is unwritable on the ro mount. Pass `BUILD=/build` so staging,
  the qmldir emit, and artifacts land in the writable build dir.
  (build-and-gate.sh uses LATTE_BUILD, a different var, so `-e BUILD=` does
  not disturb it.)
- The image ENV must carry LATTE_QML_MODULE_PATH (Fedora: /usr/lib64/qt6/qml,
  a lib64 multilib path, NOT lib/qt6/qml as on Arch) or lib-qml-env.sh
  aborts on its `${LATTE_QML_MODULE_PATH:?}` guard. Setting it in the image
  (rather than only on the podman command line, as the Arch prototype did)
  also lets the QML-loading unit tests pass under plain ctest.
- lavapipe ICD on Fedora is arch-suffixed: lvp_icd.x86_64.json (Arch:
  lvp_icd.json).
- The staged Latte modules resolve via KDE_INSTALL_QMLDIR -> lib64/qt6/qml
  on Fedora (emitted to build/latte-qmldir.txt by 18aac31b0); confirmed
  the 3 scenes that import org.kde.latte.components (applet_colorizer,
  indicator_glow, shadoweditem) find the staged tree - they render, they
  just diff by 1 LSB.
- kwin cap strip (setcap -r) is needed on Fedora exactly as on Arch:
  Fedora's kwin package also ships kwin_wayland with cap_sys_nice=ep.
- For B2 (parallel agent): the QML script-gate ctests and e2e recipes need
  `/usr/lib64/qt6/bin` on PATH (qmltestrunner, qmllint). The e2e vehicle
  additionally needs python3 + ImageMagick added to the image (this leg
  keeps the render-harness scope matching Arch's proven B3 and does not add
  them). fake-input.xml for fakepointer is at
  /usr/share/plasma-wayland-protocols/fake-input.xml (plasma-wayland-protocols
  package), same as Arch.
