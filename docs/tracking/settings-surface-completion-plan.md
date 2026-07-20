# Settings surface completion plan

Planning artifact, split for review 2026-07-20. Approval is inactive in this
foundation. The evidence-first and scaffold sequence becomes authorized only
after the dependent execution-ledger PR lands and this document includes
sections 7-9. This initiative proves that Latte-owned settings can be reached,
operated, persisted, and observed through their real interfaces. It follows the
completed `edit-mode-settings-audit-plan.md` wiring audit without treating
handler transcription or direct config seeding as end-to-end evidence.

Production behavior changes are not approved by this document. In particular,
no task-action expansion, empty-area action expansion, persisted action enum,
schema migration, or maintained-continuation divergence is approved before the
driven evidence and sign-off gates below. Exact models, enum values, D-Bus
records, and migrations are selected only after source inventory and runtime
evidence establish what is needed.

## 1. Approval boundary

Only after the dependent execution-ledger PR lands may the following work start:

- SC-F1 (the per-view source inventory and evidence ledger) and SC-F2 (the
  source-to-ledger coverage gate);
- SC-O1 (the read-only settings-control D-Bus registry) after SC-F1 defines the
  minimum evidence fields;
- SC-D1 (the pointer and keyboard control drivers) and SC-D2 (the popup and
  lifecycle driver helpers) after SC-O1;
- SC-C1 (the ComboBox and ComboBoxButton component family);
- SC-C2 (the slider and numeric-field component family);
- SC-C3 (the text-entry component family);
- SC-C4 (the checkable and grouped-button component family);
- SC-C5 (the color-control and dialog component family);
- SC-T1 (the middle-click evidence capture) for D29 (task-icon middle click
  appears to execute left-click behavior), SC-B1 (the empty-area action
  investigation) for D30 (Behavior mouse actions expose fixed booleans instead
  of full choices), and SC-W1 (the launcher-wheel regression guard) for
  D56 (pure-launcher task wheel uses inherited asymmetric activation).

No listed work is authorized by this foundation alone. After the dependency
lands, every other unchecked item remains sequenced but unauthorized for
implementation. The relevant evidence gate and explicit maintainer sign-off for
any Qt5 divergence must be recorded in this plan before an implementation agent
is farmed. A sign-off for one behavior does not approve adjacent action
expansion.

## 2. Why the earlier audit is not completion evidence

The earlier audit established useful config readbacks, exact-key diffs, handler
tests, and a catalog of 121 logical settings entries. Its evidence is narrower
than this initiative's completion contract:

- `tests/behaviorwiringaudittest.cpp` and related tests execute transcribed
  handlers against stub maps. They prove expected writes, not real-control
  operability.
- `tests/e2e/032-behavior-live-reflect.sh` checks readback agreement without
  clicking each Behavior control.
- `tests/e2e/034-tasks-config-apply.sh` seeds Tasks config directly and observes
  one `launchersGroup` effect. It does not operate the Tasks page or prove the
  other labeled effects.
- `tests/qml/tst_taskactions.qml` checks action-to-token mapping. Production
  task wheel handling does not call `TaskActions.scrollCommandFor`, and the test
  does not prove pointer receipt, target classification, model requests, or
  independent effects.
- Popup selection, sliders, text entry, keyboard paths, disabled states,
  persistence, accessibility, and abort cleanup were not exhaustively driven.

The old plan remains the wiring/readback ledger. This plan owns actual control
operation and runtime-effect evidence.

## 3. Scope

### 3.1 Per-view settings

SC (per-view settings completion) covers every concrete affordance represented
by logical entries 1-121 in `edit-mode-settings-audit-plan.md`, plus affordances
grouped inside those entries:

- the canvas ruler, edit background, rearrange mode, and edge-stick controls;
- settings-window chrome, mode switch, tabs, resize handle, and view actions;
- Behavior, Appearance, Effects, and Tasks pages;
- the Dock/Panel chooser and Latte-owned ConfigOverlay actions;
- every bundled indicator configuration page and the third-party host contract;
- every pointer button, wheel path, hold path, split-button half, popup row,
  keyboard path, and repeated applet instance found by the source inventory;
- dock and panel modes, both axes, applicable alignments, and conditional
  enabled or visible states.

Third-party applet settings internals are out of scope. Latte's action for
opening an applet settings dialog remains in scope.

### 3.2 Global settings

GS (global settings completion) starts after the per-view page units and matrix
closure. It covers the Qt Widgets and mixed QML surfaces under `app/settings/`:

- the Settings dialog shell, Layouts table, and Preferences page;
- Actions, Views, Details, Screens, and Export Template dialogs;
- add, copy, import, export, remove, switch, apply, cancel, reset, and default
  paths;
- validation, persistence, restart, and destructive rollback behavior;
- keyboard and accessibility behavior, plus nested-KWin effects on live views.

GS-F1 (the global Qt Widgets source inventory) performs a fresh source pass. The
per-view count is not reused as a proxy for global coverage.

## 4. Completion contract

Each ledger row records separate evidence for C1-C9 (the nine
control-completion properties). One aggregate green flag is not sufficient.

- **C1 Reachable:** intended mode and state combinations expose the control;
  named conditions explain hidden and disabled states.
- **C2 Operable:** real pointer and keyboard input reaches the real control.
  Popups open and close, every enabled row can be selected, buttons invoke once,
  sliders reach boundaries and interior values, and fields validate and commit.
- **C3 Right write:** only the intended config or C++ state changes, including
  documented coupled writes. Dead and stray keys fail this property.
- **C4 Runtime effect:** the labeled dock, task, window, layout, or settings
  behavior changes. Config transport alone is not evidence.
- **C5 Reflects and syncs:** initial and external state changes appear in the
  control, and interaction does not destroy the binding.
- **C6 Persists:** persistent values survive close, reopen, and restart.
  Transient actions leave no persistent residue.
- **C7 Complete choices:** every displayed choice has a handled branch and every
  supported choice is represented or deliberately hidden. The source inventory,
  not a preselected action matrix, defines the set to check.
- **C8 Clean lifecycle:** close, tab change, edit exit, abort, and object
  destruction leave no popup, pressed state, focus grab, drag, or stale registry
  generation.
- **C9 Accessible:** useful role, name, value, actions, focus order, activation,
  and rendered focus state exist where applicable.

## 5. Evidence architecture

### 5.1 Independent source inventory

SC-F1 inventories interactive QML declarations and C++/Qt Widgets affordances
before the runtime registry exists. It includes accepted buttons, handlers,
popup actions, delegates, repeated instances, and explicit non-control
exemptions. Each ledger row records source location, stable audit identity,
reachability, input paths, expected write, runtime oracle, persistence,
accessibility, novel matrix cells, and C1-C9 evidence.

SC-F2 compares the independent inventory and checked ledger in both directions.
Later registry comparison is a third source. No source may define and certify
its own coverage universe.

### 5.2 Read-only control registry

SC-O1 adds only the state needed to locate and inspect inventoried controls.
The inventory selects the exact XML and record fields. At minimum, the design
must distinguish view, surface, load generation, optional applet, audit
identity, and repeated instance; expose mapped and clipped hit geometry; report
visible, enabled, focused, and current control state; describe popup rows when a
popup exists; and remove destroyed generations.

SC-O1 lands the registry transport, serializers, lifecycle, and a fixture-backed
vertical slice. It does not register every production page in one PR. Shared
component and page units add their own records as those surfaces become driven.

The interface is read-only. Pointer and keyboard input drive controls at
reported geometry. No D-Bus setter may bypass a control. XML, serializer tests,
the observability design, the interface reference, and a usage recipe land in
the same PR.

Runtime-effect readbacks are not bundled into SC-O1. Each missing oracle found
by the ledger receives its own one-surface PR and plan item before the dependent
page or matrix unit starts.

### 5.3 Test layers

- Sanitized C++20 pure cores follow the step-2.5 law in
  `docs/reference/TESTING.md`.
- Component tests instantiate production control types and assert signals,
  popup state, rows, disabled behavior, focus, and cleanup.
- Page tests load one real page with production-shaped context and drive controls
  without screen-coordinate guesses.
- Nested tests use `scripts/run-e2e.sh`, fakepointer, keyboard injection, D-Bus,
  and compositor state. Pixels are reserved for visual effects or
  state-versus-render disagreement.
- Every runtime claim names a fixture, operation, requested state, independent
  effect, negative control, and permanent test ID before implementation.
- Every defect fix is reproduced red before the fix and green after it. Temporary
  probes and reverts remain uncommitted.

## 6. Evidence gates and defect dispositions

### D29 (task-icon middle click appears to execute left-click behavior)

Status remains OPEN and unproven. Live observation on 2026-07-19 established a
task-icon symptom, not the exact row or dispatch path. Current code dispatches
`middleClickAction` for non-launcher rows, while a pure launcher calls
`activateTask()`. Both branches are inherited from Qt5.

After the dependent execution-ledger PR lands, SC-T1 is the first and only
authorized D29 task. It must capture one physical middle click end to end and
record all five facts together:

1. exact task row kind and stable target identity;
2. stored `middleClickAction` value at the moment of input;
3. QML event recipient and accepted-button path;
4. exact command or tasks-model request emitted, including no request;
5. an independent model, window, process, or compositor effect.

The capture starts with the observed configuration. Additional row kinds are
controls only after the first path is known. Temporary instrumentation is
allowed in a disposable worktree and is removed before the evidence PR.

No solution, action enum, persisted schema, target/action matrix, group policy,
or unsupported-value policy is selected in advance. SC-T2 records whether the
capture is a config misunderstanding, inherited Qt5 behavior, or a real defect.
Any proposed behavior that differs from Qt5 requires explicit maintainer sign-off
under the orchestrator rules before a production task is added. An action-
surface expansion is a separate continuation proposal and cannot be attached to
D29.

### D30 (Behavior mouse actions expose fixed booleans instead of full choices)

Status remains OPEN and code-grounded. `BehaviorConfig.qml` uses two checkable
buttons backed by `dragActiveWindowEnabled` and
`closeActiveWindowEnabled`. `EnvironmentActions.qml` uses the first boolean for
left-button drag and double-click maximize/restore, and the second for
middle-click close. The controls have no action model or popup. This is inherited
Qt5 behavior, not a Qt6 popup regression.

SC-B1 inventories the exact current gestures, event ownership, config defaults,
runtime requests, target retention, capabilities, and protocol surface. It also
compares Qt5 and both reference forks. SC-B2 then presents the evidence and the
smallest alternatives: retain and clarify the boolean UI, or approve a recorded
maintained-continuation divergence with a bounded set of choices.

No expansion is approved yet. If a divergence is approved, typed decision core,
window-system API additions, migration, UI, observability, and each nested
gesture matrix remain separate PR units. Exact action values and models are
chosen after SC-B1 and recorded at SC-B2. Missing `LastActiveWindow` or Wayland
operations are added one operation family per PR, not as one protocol sweep.

### D56 (pure-launcher task wheel uses inherited asymmetric activation)

Status is ACCEPTED as Qt5-faithful behavior. A disposable nested run at
`origin/main` commit `6765b2320` proved that a pure launcher receives wheel
input directly in `TaskMouseArea`. A positive step calls
`TaskItem.activateLauncher()`, then `TasksModel.requestActivate`; a negative step
does nothing for `ScrollTasks` and `ScrollToggleMinimized`. `ScrollNone` refuses
the handler unless manual scrolling is enabled. With manual scrolling enabled
and no overflow to consume the step, the same positive launcher activation
occurs. Production does not call `TaskActions.scrollCommandFor` on this path.

`git blame` traces the handler and positive launcher call to Qt5 commits
`2d6b482d5f` and `e642087e31`; both reference forks retain the behavior. This is
not D29 and not a Qt6 routing regression. SC-W1 adds a permanent regression test
for the observed positive, negative, `ScrollNone`, manual-scroll, and no-overflow
branches without changing behavior.

### Existing defect boundaries

- D24 (TypeSelection Dock/Panel presets write two dead keys) remains OPEN on
  current main. SC-M1 owns only removal of the four schema-absent writes and the
  focused source/config guard. It is not part of D30 or any Behavior action
  expansion.
- D31 (valid Justify splitter moves reset after restart) is FIXED by PR #73 and
  is outside this plan. Existing persistence evidence may be reused, but no
  settings-completion unit owns or reopens it.

## Execution-ledger dependency

Implementation approval is not active from this partial plan. The dependent
execution-ledger PR must append sections 7-9 before any listed implementation or
investigation unit starts, including the evidence-first units in section 1.
