# <img src="logo.png" width="48"/> Latte Dock (Plasma 6 / Qt 6)

> **Continuation notice**: this is a from-scratch **Plasma 6 / Qt 6 /
> Wayland** port of KDE's [latte-dock](https://invent.kde.org/plasma/latte-dock),
> forked with the full original history intact and maintained by
> [whimbree](https://github.com/whimbree) as a living continuation.
> Upstream development stopped in the Plasma 5 era; this fork carries the
> codebase to Plasma 6.6 / Qt 6.11 / KDE Frameworks 6 and is developed
> against a real daily-driver Wayland session. X11 is best-effort: it must
> compile, but it is not run-tested and never blocks Wayland work.

Latte is a dock based on plasma frameworks that provides an elegant and
intuitive experience for your tasks and plasmoids. It animates its contents
with a parabolic zoom effect and tries to be there only when it is needed.

**"Art in Coffee"**

Screenshots
===========

A floating dock at rest:

![](docs/screenshots/dock.png)

Parabolic zoom with live window previews on hover:

![](docs/screenshots/parabolic-hover.png)

Edit mode, with the blueprint grid and widget rearranging:

![](docs/screenshots/edit-mode.png)

Applet popups, themed and resizable (edge-drag to resize, size persists
per applet):

<img src="docs/screenshots/volume-popup.png" width="320"/>

Status
======

Working and in daily use on Wayland: multi-dock and multi-screen layouts,
the tasks applet with live window previews, group thumbnails, badges and
audio indicators, parabolic zoom, edit mode with drag rearranging,
per-applet context menus and settings, the three bundled indicator styles,
layer-shell placement with struts and auto-hide/dodge visibility modes,
layout management with templates and import/export, applet colorization,
and the full settings UI. Beyond upstream parity, the port has grown
continuation features of its own, the first being resizable applet popups
with per-applet size persistence.

Roadmap
=======

The real tracker is [docs/PORTING_PLAN.md](docs/PORTING_PLAN.md): 13
phases, one commit-traceable checklist item per task. The coarse picture:

- [x] Build system, Qt 6 / KF 6 migration, Wayland layer-shell backend
- [x] QML controls and rendering migration (Plasma 6 component stack)
- [x] Task manager subsystem (previews, groups, badges, launchers)
- [x] Widget management, drag-and-drop, edit mode
- [x] Nix packaging (flake with package, overlay and NixOS module)
- [x] Resizable persistent applet popups (continuation feature)
- [ ] Layout/config persistence, session shutdown, multi-screen edge cases
      (the open phase; live-driven fixes land here continuously)
- [ ] Theming and colorization polish audit
- [ ] Stabilization: the QML logic extraction initiative
      ([docs/QML_EXTRACTION_PLAN.md](docs/QML_EXTRACTION_PLAN.md)) is
      moving feel-critical QML logic into tested, sanitized C++ cores -
      4 of 25 units executed so far
- [ ] CI/CD: the local gates (build-check, QML compile gate, qmllint
      ratchet, coverage ratchet) are pure shell over cmake/ctest and
      CI-portable by design; the hosted pipeline itself is not stood up yet
- [ ] Automated end-to-end GUI testing: headless interaction tests exist
      today (offscreen qmltest driving the real shipped QML); the planned
      microvm-based GUI CI with compositor-level pointer driving is not
      built yet
- [ ] Distro packaging beyond NixOS (no PPA/COPR/AUR yet; the classic
      CMake install works everywhere the dependencies exist)
- [ ] Companion applets as sibling repos consumed by flake input: the
      Latte separator applet, then a full Qt 6 port of
      [applet-window-appmenu](https://github.com/psifidotos/applet-window-appmenu)
- [ ] Further continuation features: dock replication, background color
      picker

How it is built
===============

Every fix names its root cause and the evidence in its commit body, and
the tree defends itself: 21 ctest entries including pure-core unit tests
that run under ASan+UBSan, a QML compile gate that loads every shipped
QML file in a real engine, contract tests that pin the exact libplasma/
KSvg/Qt behaviors the dock relies on (so a dependency bump fails in ctest
instead of misbehaving on screen), a qmllint ratchet with a
committed baseline that only shrinks, and a coverage ratchet that makes
untested cores un-mergeable. Feel-critical changes (the parabolic engine,
the preview pipeline) additionally get live verification on a running
Wayland session with injected pointer glides and screenshot comparison
before they merge. [docs/TESTING.md](docs/TESTING.md) carries the
standard; [docs/session-handoff.md](docs/session-handoff.md) carries the
current working state.

Relationship to other Plasma 6 ports
====================================

Two community ports exist ([ruizhi-lab/latte-dock-ng](https://github.com/ruizhi-lab/latte-dock-ng)
and [CaptSilver/latte-dock-qt6](https://github.com/CaptSilver/latte-dock-qt6),
both Wayland-only). Both were evaluated in depth, running and
live-debugging them rather than reading commit logs, before this fork
started fresh from upstream. They are tracked as reference material:
their fixes are reviewed periodically and re-derived here as new commits
when they are correct, never merged or cherry-picked wholesale. The
analysis and the sync process live in the repository docs.

Installation
============

### Requirements

- **Plasma >= 6.5**, **Qt >= 6.6**, **KDE Frameworks >= 6.5**
- LayerShellQt, PlasmaWaylandProtocols
- A Wayland session (X11 compiles but is untested)
- Tools: cmake >= 3.16, ninja or make, extra-cmake-modules, a C++20
  compiler

### NixOS (flake)

Add the flake as an input and enable the module:

```nix
# flake.nix
inputs.latte-dock.url = "github:whimbree/latte-dock";

# in your nixosSystem call
nixpkgs.lib.nixosSystem {
  system = "x86_64-linux";
  modules = [
    inputs.latte-dock.nixosModules.default
    ./configuration.nix
  ];
};
```

```nix
# configuration.nix
{
  programs.latte-dock.enable = true;
}
```

The module installs the dock system-wide (required so KWin finds the
`.desktop` entry for window-management integration and the shell/applet
packages resolve), building it against **your** nixpkgs' Qt/KF6 stack,
not this flake's development pin. `overlays.default` is also exported if
you prefer wiring `pkgs.latte-dock` yourself, and one-off builds work
without any wiring:

```bash
nix build github:whimbree/latte-dock
nix run github:whimbree/latte-dock
```

### From source (any distro)

```bash
git clone https://github.com/whimbree/latte-dock.git
cd latte-dock
cmake -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr
cmake --build build --parallel
sudo cmake --install build
```

### Development builds

Development happens through the flake devShell, which pins the exact
Qt/KF6/Plasma revisions the port is verified against:

```bash
nix develop -c cmake -B build -G Ninja
nix develop -c cmake --build build
scripts/restart-staged.sh -d   # staged run: throwaway config home,
                               # private QML/plugin staging, never
                               # touches your real Plasma or Latte config
```

`scripts/` carries the verification tooling: `build-check.sh` (both X11
variants + full ctest + the ratchets), the QML gates, a KWin
window-geometry dumper, and a Wayland pointer injector for driving the
live dock headlessly.

Running
=======

```bash
latte-dock
```

or launch **Latte Dock** from the applications menu. Layouts live in
`~/.config/latte/`; upstream Plasma 5 Latte layouts import cleanly.

Credits
=======

- **Michail Vourlakos** and the KDE community: the original Latte Dock,
  a decade of upstream work this port stands on.
- [Varlesh](https://github.com/varlesh): logos and icons.
- The reference ports by [ruizhi-lab](https://github.com/ruizhi-lab/latte-dock-ng)
  and [CaptSilver](https://github.com/CaptSilver/latte-dock-qt6), whose
  independently-found fixes are periodically reviewed and credited in
  commit messages where their work informed ours.

License
=======

Licensed under **GPL-2.0-or-later**, same as upstream. The original KDE
repository remains at https://invent.kde.org/plasma/latte-dock with the
Plasma 5 codebase and its bug tracker.
