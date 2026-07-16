# Stabilization execution prompt (post-extraction continuation)

Re-runnable. Written 2026-07-16, after the QML extraction initiative
completed. Give this file to a fresh session to drive the remaining
work in priority order. It assumes CLAUDE.md has been read (the
working agreements, root-cause law, regression discipline, copyright
rules, code-clarity laws and Q_ASSERT truths there are binding and are
not repeated here).

## Standing context

- Repo: ~/Projects/latte-dock, GitHub whimbree/lattecotta-dock
  (project name Lattecotta Dock; binary/D-Bus names stay latte).
- docs/PORTING_PLAN.md is the tracker: its "Where we are" section
  carries the ranked high-priority list; every task is a checkbox with
  a Commits: line - tick and fill as you land work.
- docs/QML_EXTRACTION_PLAN.md is COMPLETE; its ledger's executed notes
  name the still-owed live-verification recipes. Do not reopen units;
  new cores follow the same step-2.5 law (sanitized unit tests via
  latte_add_unit_test, QT_FORCE_ASSERTS, type discipline, qmllint
  ratchet strict-on-touch, coverage-ratchet pairing).
- Gates before any merge: full ctest green, scripts/coverage-ratchet.sh,
  scripts/qmllint-gate.sh (baseline only shrinks), both WITH_X11
  variants build. Use `nix develop -c` for all build/test commands.
- Live verification on the author's real Wayland session is authorized.
  Tools: scripts/restart-staged.sh (-d for the throwaway profile,
  --user-config for the real one - ALWAYS restore --user-config when
  done), ~/.local/bin/fakepointer (glide in small steps, never
  jump-click; scroll takes detents+gap), scripts/tools/dumpwins.sh,
  spectacle -b -n, KWin scripting via busctl for window manipulation,
  kwriteconfig6 against the throwaway layout for config flips (edit
  while the dock is STOPPED, then restart).
- Parallel work: spawn worktree subagents per unit of work where tasks
  are disjoint; the orchestrator merges serially (rebase onto master,
  ff-merge, full gates, live checks, ledger/plan tick, push, prune).
  LIMITS (my direction 2026-07-16, cap raised the same day): at most
  4 subagents at a time (not counting the orchestrating session), and
  every subagent keeps a running log of what it did and found in
  docs/agent-logs/ (one file per dispatch, named
  YYYY-MM-DD-<short-task-slug>.md) - the ledger strategy that keeps
  models and subagents accountable over long horizons.
  Merge lessons already paid for: tests/units/CMakeLists.txt and
  plugin-registration files are both-append unions; tests/ratchet-
  baseline count = union size with a sorted entry list; tests/qmllint-
  baseline is taken from ours then REGENERATED with --write-baseline
  after a full build; plugins.qmltypes is NEVER hand-merged - always
  regenerate with the qmlplugindump recipe in the file's own header
  against the freshly staged tree, and verify every expected singleton
  name appears before committing.
- Push after each landed, verified chunk. Prefer new commits over
  amending. Conventional commits with root-cause bodies.

## Priority order

Work top to bottom. Each item names its home in docs/PORTING_PLAN.md;
read the full checklist item there before starting - this list is the
map, not the territory.

(Icon note: Varlesh's original icon set and logo are the PERMANENT
choice, through and beyond the Lattecotta package rename - see that
plan item for the recorded decision. Never land replacement icons.)

1. **Session shutdown/logout teardown** (Phase 8): one deliberate
   sequence; unload the Corona's dependents in explicit dependency
   order. This is the crash-on-logout class. Instrument a real
   logout/login cycle on the throwaway session before and after.

2. **Startup latency + retry-exhaustion deadlock** (Phase 8): measure
   first (the plan item records the live observation), fix the
   deadlock, then attack latency with evidence.

3. **Dock visibility across screen lock/unlock** (Phase 8): reproduce
   with loginctl lock-session/unlock-session on the throwaway.

4. **Cloned-view applet-order sync** (Phase 8): the deferred-sync gap
   (a clone's containment can finish initializing before
   structuralSyncReady() is true and nothing re-triggers). Fix is
   described in the item. Also the prerequisite for the Replicate Dock
   continuation feature (docs/dock-replication-design.md).

5. **Edit-mode polish cluster** (Phase 7): entry/exit detection
   research FIRST (read the phase notes - a reference fork needed 8+
   attempts), then drag-reorder jitter, double-click widget add,
   position-aware drop insertion, icons-stuck-behind-close-overlay.

6. **Layer-shell struts/exclusive-zone + kde_output_order_v1** (Phase
   4): align with what Plasma itself uses; regression-test multi-
   screen placement with dumpwins after every change.

7. **Settings-window control audit** (Phase 8): every control on every
   page against Qt5 semantics; the Tasks-config lesson (a page that
   renders but silently does nothing) is the failure mode to hunt.

8. **The accessibility/automation quartet** (Phase 10 requirements
   subsection - read it in full; these are requirements, not polish):
   a. Keyboard navigation for EVERYTHING (audit surface-by-surface,
      written shortcut map, focus order + visible indicators).
   b. Observability first - D-Bus exposure for everything (one
      reviewed interface design; any subsystem's state cheaply
      inspectable, anything a test drives gets a surface, state
      readbacks replace pixel-peeping; safety rules in the plan item
      and CLAUDE.md's Observability-first section are binding: reads
      expose state never execution, mutations stay coarse or
      debug-gated). This principle also applies to every OTHER item
      in this list: whatever you fix, ship its observability surface
      in the same unit of work.
   c. Convert nondeterministic e2e tests to deterministic ones (live
      cursor ONLY where pointer delivery is itself under test - those
      keep fakepointer).
   d. Full AT-SPI support (Accessible roles/names on every interactive
      item, focus events, Orca pass as acceptance). Do b before c;
      a and d together (they share the focus/role work).

9. **CaptSilver testability adoption** (Phase 10; REPLACES the
   microvm/hosted-CI item, my direction 2026-07-16): study
   latte-dock-qt6's testability improvements - every test they have
   that we don't (63 test files vs our 39), and especially their
   committed visual regression harness ("sceneprobe"): golden PNGs of
   the parabolic zoom, multieffect, shadows etc., rendered and diffed
   per GPU backend with a proper per-channel tolerance comparator.
   HARD CONSTRAINT (my clarification): our CI must run with just KVM
   or some VMM - NO real-dGPU dependency. Their harness's dGPU golden
   arm is not an adoption target; what we want is the
   lavapipe/software-raster path (deterministic software rendering is
   what makes VM-only CI viable). Adopt as much as fits: the analysis
   lands as a docs/ file first (what to adopt, transplant cost,
   conflicts with our upstream-shaped tree), then the adoption work
   is executed as normal plan items. The microvm compositor harness
   idea is superseded by this - lavapipe-rendered golden scenes cover
   the headless-GUI-CI need for rendering; pointer-delivery e2e keeps
   fakepointer on the live session for now.

10. **The tail**: extraction ledger live-verification leftovers (each
    executed note names its recipes; two need the author's hands:
    Meta+number badges, real file drags), known-bug-list sweep,
    WindowId newtype hardening, stuck-overlay and uninvoked-config
    findings, Phase 9 color-group audit, Phases 2/3 mechanical tail.

## Session protocol

Operate autonomously with a long horizon. For each item: read the plan
item and its phase notes, design before code, tests first where a core
is touched, land in small bisectable commits, run the gates, live-verify
against the running dock (throwaway first, real config for the final
check when the change is user-visible), tick the plan checkbox with
commit hashes, push, and keep docs/session-handoff.md current so an
interruption loses nothing. When a live check finds a defect, stop and
root-cause it before continuing the checklist - found defects outrank
planned work. Flag anything needing the author's physical input and
move on rather than blocking.
