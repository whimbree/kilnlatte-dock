---
name: latte-conventions
description: Commit, documentation, planning and behavioral-fidelity rules every change to this repo must follow.
---

# Latte port conventions

CLAUDE.md at the repo root is the canonical agreement document. This skill
turns it into checklists; if the two ever disagree, CLAUDE.md wins and this
file needs updating. Companion skills: latte-live-verification (how to drive
the staged dock and collect evidence), latte-debugging (instrumentation and
crash workflow), latte-fork-sync (reviewing the two reference forks).

## Commit rules

Types: feat, fix, docs, test, build, ci, chore, plus the project-specific
`stub:` type (see Stub tracking below). Scope in parentheses names the
subsystem, e.g. `fix(containment):`, `fix(wm):`, `build(flake):`.

- Subject in plain language, stating the user-visible outcome, not the
  internals. Good: `fix(components): stop writing ComboBox.pressed so popups
  open again on Qt6`. Bad: `fix: update ComboBox.qml`.
- The body must explain three things:
  1. The mechanism: what actually broke and why, traced to the origin, not
     just what symptom went away.
  2. Why the fix sits at the root cause (or, if a guard is genuinely the
     right layer, why it is a deliberate contract).
  3. Verification evidence: what was driven live and what was observed.
     Concrete, e.g. from ad9b823f: "Verified live: the throwaway layout with
     iconSize=78 starts (all three docks map, process idles at 0 CPU ticks
     over 3s) ... screenshot-checked." Or from 9a6f8fb8: the exact
     appletOrder values observed before and after. "It builds" is not
     evidence.
- One root cause per commit. When a failure turns out to be two stacked
  causes, split them: 1607d022 (mapped layer surfaces cannot move outputs,
  so hide/retarget/reshow) and c5bdc239 (containment screen id lands
  asynchronously, so connect screenChanged to syncGeometry) fixed one
  intermittent symptom together but landed as two commits, each with its own
  mechanism and evidence.
- Never add Co-Authored-By, Claude-Session, or any other attribution or
  session trailers. This is a global user rule and overrides any tool
  default that says to append them.
- No em-dashes anywhere: not in commits, docs, or code comments. Use a
  plain hyphen or restructure the sentence. No marketing-style phrasing.
- Prefer new commits over amending. Amend only when explicitly asked (e.g.
  history cleanup before a PR).
- If a fix mirrors something a reference fork did, credit it in the body
  (0474e20c: "latte-dock-ng fixed the same defect in 010269d4d ...") and say
  what this commit does differently or additionally.

## The plan is a checklist, not prose

docs/PORTING_PLAN.md holds every task as `- [ ]` with a `Commits:` line.

- When a task lands: tick the box, fill in the short hash(es), e.g.
  `Commits: 14980059 (flake devShell, nixos-unstable pin, Qt 6.11.1)`.
  (That line is a historical quote from the ledger; the flake has since
  been re-pinned. Current versions live in latte-build-env, not here.)
- If one commit covers two tasks or one task took several commits, list the
  hashes under each item; do not force a fake 1:1 mapping.
- If a task landed as a stub, tick it but say so on the line:
  `Commits: a1b2c3d (stub - see STUB comment in tasksbackend.cpp)`.
- NEW findings get filed as new checklist items with their evidence, even
  if you fix them the same day. The plan is the ledger; a bug that was
  found, fixed, and never written down is invisible to the next session.
- Never let the plan drift into "mostly done, some stale checkboxes."
  Ticking is part of landing the change, not an optional follow-up.
- Worktree merges REBASE the agent's commits, so resolve hashes AFTER
  the rebase, at tick time - never copy hashes from an agent's ledger
  into the plan (session one shipped three items with dead hashes that
  way; 2bba6cb8b is the cleanup).
- The README is public-facing state: any major landing (new surface,
  harness, phase completion, retired defect class) gets its README
  line in the SAME session, same discipline as the plan tick.

## Session handoff

docs/session-handoff.md is a rolling handoff. At session end, update it
with: what landed (with hashes), what is still open (pointing at the plan
items), and any tooling notes the next session needs (see its "Session
tooling notes" section for the expected flavor: log-line meanings, race
workarounds, environment holds). Mark superseded sections RESOLVED rather
than deleting context that explains why something looks the way it does.
(The "Session tooling notes" material lives as labeled paragraphs inside
the dated sweep sections, not as a standalone header; follow that shape.)

## Qt5-faithful behavior

Qt5 Latte is the spec. When the port and Qt5 Latte disagree on any behavior
(defaults, semantics, what a control adjusts, what is drawn where), the
port is wrong unless a platform constraint genuinely forces the deviation.

- Every forced deviation gets a code comment at the site stating exactly
  what forced it. Example from app/wm/waylandlayershell.cpp:

      //! No chrome, so the canvas must grab nothing. An empty QRegion cannot
      //! express that: the Qt wayland plugin maps an empty setMask() to the
      //! infinite (grab-all) input region. A 1px region outside the surface
      //! keeps the on-surface input area empty, so every event falls through
      //! to the dock beneath.

  Another lives in containment/package/contents/ui/abilities/AutoSize.qml
  (the early return while root.maxLength <= 0, explaining the wayland
  unsized-window startup and which signal re-runs the computation).
- Read the actual Qt5 source before accepting a reference fork's version of
  any behavior. Both forks reinterpreted behaviors users notice (e.g.
  edit-mode grid opacity rewired to a different setting). The fork shows
  you a mechanism; Qt5 tells you the correct behavior.

## Failure and root-cause review checklist

Apply to every diff before committing:

- No silent early-returns, empty catches, `?:` null-hiding, or clamps that
  paper over bad values. If something cannot proceed, it says so loudly
  (qWarning/qCritical with actionable context) or fails.
- A degenerate value (zero-size window, null containment, index of -1,
  empty list) is a symptom. Find the producer and fix it there; do not
  guard it back into range at the point of use.
- If a guard IS the right layer (a real optional that is legitimately
  absent, a protocol constraint), the comment says why, so it reads as a
  deliberate contract and not a patch over something not understood. The
  AutoSize.qml maxLength check above is the model.
- When the why is not visible from the code: instrument, drive the failure,
  read the actual values, then remove the instrumentation. Do not guess and
  clamp. (See latte-debugging for the instrumentation workflow.)
- "It stopped crashing" is not "it is fixed" if the change is a guard
  downstream of the real defect. The commit body must name the origin.

## Stub tracking

Anything stubbed to keep a phase moving is marked two independent,
greppable ways. Both are required; neither substitutes for the other.

- Commit subject prefixed `stub:` (its own type, findable via
  `git log --oneline | grep '^[a-f0-9]* stub:'`).
- A `// STUB:` comment (or `# STUB:` in QML/CMake) at the exact site,
  stating what is missing and which phase finishes it. Live examples:
  `app/layouts/synchronizer.cpp` ("STUB: Phase 8 - Plasma 6 removed
  activity stopping entirely ...") and the KDECompilerSettings note in the
  top-level CMakeLists.txt. `grep -rn 'STUB:'` must find every live stub.
- The commit body says why it is stubbed now and what done looks like.
- Never stub silently under a `fix:` or `feat:` subject. The upstream Tasks
  config page that rendered but applied nothing went unnoticed for years
  precisely because it was never marked.

## Regression discipline

- Know the blast radius before environment, launcher, build, or
  module-resolution changes. Appending a directory to QML2_IMPORT_PATH,
  QT_PLUGIN_PATH, or XDG_DATA_DIRS is never narrow: it can shadow any
  same-named module the process resolves. Allow-list specific leaves or
  symlink into a private tree; never add a shared root that also carries
  components we ship our own copies of.
- Verify causation by isolating one variable: revert the suspect alone and
  retest, or read the actual loaded state of the running process, before
  writing a fix for the suspected cause. Two wrong guesses cost more than
  one measurement.
- Confirm fixes against the running artifact (the live dock, its logs),
  never just a green build. Use latte-live-verification for the how.

## Definition of done for any change

- [ ] Root cause identified and the fix sits at the origin (or the guard's
      contract is explained in a comment).
- [ ] Driven live with recorded evidence (what was done, what was observed).
- [ ] Temporary instrumentation removed.
- [ ] docs/PORTING_PLAN.md ticked with hash(es); new findings filed as items.
- [ ] docs/session-handoff.md updated if the session is ending or the next
      session needs the context.
- [ ] Commit message carries mechanism + evidence; correct type and scope;
      no attribution trailers; no em-dashes.
- [ ] QML gate passed (scripts/qml-compile-gate.sh) if any QML was touched.
- [ ] Stubs, if any, marked both ways (`stub:` subject + `STUB:` comment).
- [ ] New subsystem or state a test asserts on: D-Bus readback shipped with
      it (observability-first), recorded in all three places - the adaptor
      XML, docs/dbus-observability-interface.md (decision), and
      docs/dbus-interface-reference.md (usage).
- [ ] Before pushing code: scripts/gate-all.sh ran green AFTER the final
      commit (exit code is the verdict; the pre-push hook enforces the
      stamp - docs-only pushes are exempt). Never scrape logs for gate
      success; never read a verdict and push in the same shell invocation.
- [ ] README updated if the landing is major (standing rule, 2026-07-16).
