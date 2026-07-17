# 2026-07-16: layer-shell probe guard + WindowId newtype hardening

Working ledger for the two-part pass on branch
`worktree-agent-a4de546c2d2153134`. Merge will rebase; hashes below are
branch-local.

## Part 1: guard the LATTE_LAYERSHELL_HAS_SET_SCREEN probe

### Probe analysis

- Site: top-level CMakeLists.txt (try_compile against
  cmake/CheckLayerShellSetScreen.cpp, linking LayerShellQt::Interface).
  The result variable is a NORMAL variable, so the probe re-ran on every
  configure and the `add_definitions` branch adopted whatever that run
  said. One configure in a broken environment (system cmake outside the
  devshell, torn toolchain) silently flips the define; layer-shell
  output pinning then falls back to QWindow::setScreen() with only a
  STATUS line nobody reads.
- What it probes: whether LayerShellQt::Window::setScreen(QScreen*)
  exists. Verified against the PINNED dependency: layer-shell-qt 6.6.5
  (/nix/store/5517bbc2...-layer-shell-qt-6.6.5-dev/include/LayerShellQt/window.h
  line 132) ships the member. So in this environment a probe failure is
  never a real "no" - it is an environment defect.

### Chosen guard semantics

Two independent defenses, mirroring the flavor of 27668839a
(pinned-cmake re-exec guard):

1. Failure triage by diagnostic, not by exit code: the only failure
   accepted as a legitimate "API absent" answer is compiler output
   matching `no member named.*setScreen` (gcc and clang shapes, quote
   style agnostic). Any other failure output (missing header, dead
   compiler, link failure) is an environment defect and configuration
   stops with FATAL_ERROR carrying the full probe output. This stays
   correct across re-pins: a future layer-shell-qt that really removed
   the member produces exactly the missing-member diagnostic and flows
   to a quiet FALSE.
2. The answer is cached (INTERNAL) keyed on LayerShellQt_DIR: a plain
   reconfigure reuses the cached answer instead of re-probing, and
   re-pinning layer-shell-qt (new store path, new LayerShellQt_DIR)
   re-probes automatically. This makes the latte-build-env skill's
   "probes cache" claim actually true - before this the probe never
   cached.

### Verification (see commit body too)

- fresh configure in the devshell: probe runs once, STATUS "available",
  CMakeCache carries LATTE_LAYERSHELL_HAS_SET_SCREEN=TRUE.
- reconfigure: no re-probe (proven by making a re-probe impossible -
  probe source temporarily renamed - and reconfiguring successfully).
- broken-env simulation: probe source temporarily given an unresolvable
  #include, fresh build dir; configure dies with the FATAL_ERROR and
  the probe output names the missing header.
- legit-absence simulation: probe call temporarily renamed to a
  nonexistent member; fresh configure proceeds to FALSE + the
  "not available" STATUS instead of FATAL.

## Part 2: WindowId newtype hardening

### Newtype design

`app/wm/windowid.h`, class Latte::WindowSystem::WindowId, QByteArray
storage (zero conversion from KWayland uuid()):

- default ctor = the documented no-window id (isEmpty() true);
- named factories only: fromWaylandUuid(QByteArray),
  fromX11WId(quint64) (0, X11 None, maps to the empty id);
- std::optional<quint32> toX11WId(): checked decimal parse, nullopt for
  empty and for malformed bytes - the silent-0 toUInt() becomes a
  type-enforced absence;
- bytes() for the QVariant/QML and logging boundaries (the QML winId
  property stays QVariant-of-QByteArray per 8e8cdf31);
- operator== and operator< (QMap/QList keys), QDebug streaming;
- implicit conversion from QByteArray/char* designed out; pinned by
  static_asserts in the unit test.

### Conversion sequencing (why the chunks are shaped this way)

The type flip itself is atomic: every signature in wm/ shares the
alias, so "one subsystem per commit" cannot hold across the flip
without giving the newtype temporary implicit conversions, which would
defeat the explicit-construction guarantee the test pins. Instead all
SEMANTIC changes land as their own pre-flip commits while WindowId is
still QByteArray (each independently buildable and revertable), and the
flip commit is purely mechanical renames:

1. fix(wm): checked X11 id parsing (the ok-flag sites) - real behavior
   change, lands alone.
2. refactor(view): the wayland lazy re-resolve sites - record the stale
   numeric premise, preserve behavior exactly.
3. feat+test: the newtype header and its unit test (standalone).
4. port(wm): the mechanical flip.

### Findings hit along the way

- xwindowinterface has MORE ok-ignoring parse sites than the six the
  plan item counted: toUInt() appears across ~15 functions plus two
  toInt() sites (requestActivate, requestToggleMaximized's NETWinInfo).
  All funneled through one checked parse.
- lattecorona.cpp onColorSchemeChanged (X11 branch) parses a D-Bus
  string with toULongLong() ignoring ok - external boundary, same
  family.
- waylandinterface activeWindow() returns `0` - a null char* silently
  constructing the empty QByteArray. Exactly the implicit-conversion
  hazard the newtype removes.
- The three `isPlatformWayland() && id.toInt() <= 0` sites
  (positioner/subwindow/subconfigview trackedWindowId()) are a stale
  numeric premise: wayland ids are uuids, uuid.toInt() is 0, the check
  is constant-true, so every call re-resolves. Deliberately preserved
  as an unconditional wayland re-resolve (not tightened to isEmpty()):
  the subwindow reshow hack remaps surfaces with a fresh uuid and
  latteWindowAdded only fires for isAcceptableWindow() windows, so
  skip-taskbar subwindows may depend on the lazy re-resolve. Tightening
  needs a live session; flagged for merge-time verification.

### Chunk notes

(filled as commits land)

### Gate results

(filled at the end)

### Final commit list

(filled at the end)
