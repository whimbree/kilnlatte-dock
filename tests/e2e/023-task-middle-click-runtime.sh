#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Bree Spektor
# SPDX-FileCopyrightText: 2026 Latte Dock contributors
# SPDX-License-Identifier: GPL-2.0-or-later
# e2e-mode: nested-only
#
# SC-T5 (the permanent runtime-effect acceptance for D29, task-icon middle
# click appears to execute left-click behavior): drive the production
# TaskMouseArea with one real fakepointer middle click per phase. SC-T3 (the
# D29 narrow middle-click dispatch readback) proves which request was selected;
# KWin and viewTasksData independently prove its effect. The offered None action
# must still record delivered input without changing any window or task state.
set -uo pipefail
# shellcheck source=lib.sh
source "${E2E_REPO:?run through scripts/run-e2e.sh}/tests/e2e/lib.sh"

fixture="$E2E_REPO/tests/e2e/fixtures/sc-t5"
fixture_app_id="org.kde.latte.sc-t5"
desktop_id="$fixture_app_id.desktop"
launcher_url="applications:$desktop_id"
window_title="latte-sc-t5-window"
fixture_data="$E2E_RT/sc-t5-data"
fixture_binary="$fixture_data/bin/latte-sc-t5"
fixture_desktop="$fixture_data/applications/$desktop_id"
fixture_record_log="$fixture_data/process-records"

export XDG_DATA_HOME="$fixture_data"
export SC_T5_PROCESS_RECORDS="$fixture_record_log"

backup=""
backup_prefix="$E2E_RT/sc-t5-layout-backup."
backup_ready=false
acceptance_completed=false
view=""
tasks_applet=""
launchers_key=""
config_group=()
status=0
target_x=""
target_y=""
pre_click_windows=""
pre_click_processes=""
pre_click_tasks=""
effect_windows=""
effect_processes=""
effect_tasks=""

read_dock_pid() {
    local pid status
    pid="$(e2e_dock_pid)"; status=$?
    if (( status != 0 )) || [[ ! "$pid" =~ ^[1-9][0-9]*$ ]]; then
        echo "read_dock_pid: invalid dock pid '${pid:-missing}' (status $status)" >&2
        return 1
    fi
    echo "$pid"
}

json_array_count() {
    python3 -c 'import json,sys
value = json.load(sys.stdin)
assert isinstance(value, list)
print(len(value))'
}

fixture_windows() {
    local raw status
    raw="$(e2e_kwin_js "var rows = [];
for (const w of workspace.windowList()) {
    if (w.resourceClass === '$fixture_app_id') {
        rows.push({id: String(w.internalId), resourceClass: String(w.resourceClass), caption: String(w.caption), active: workspace.activeWindow === w, minimized: Boolean(w.minimized)});
    }
}
print('@TAG@|' + JSON.stringify(rows));")"; status=$?
    (( status == 0 )) || { echo "fixture_windows: KWin query failed with status $status" >&2; return "$status"; }
    python3 - "$raw" "$fixture_app_id" "$window_title" <<'PY'
import json
import sys

rows = json.loads(sys.argv[1])
assert isinstance(rows, list)
assert all(row["resourceClass"] == sys.argv[2] for row in rows)
assert all(row["caption"] == sys.argv[3] for row in rows)
rows.sort(key=lambda row: row["id"])
print(json.dumps(rows, separators=(",", ":"), sort_keys=True))
PY
}

recorded_processes() {
    [[ -e "$fixture_record_log" ]] || { echo '[]'; return 0; }
    [[ -f "$fixture_record_log" ]] || { echo "recorded_processes: $fixture_record_log is not a file" >&2; return 1; }
    python3 - "$fixture_record_log" "$fixture_binary" <<'PY'
import json
import pathlib
import sys

records = []
seen = set()
for number, line in enumerate(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8").splitlines(), 1):
    parts = line.split("|", 2)
    assert len(parts) == 3, f"malformed process record line {number}"
    pid, start_time, executable = parts
    assert pid.isdigit() and int(pid) > 1
    assert start_time.isdigit()
    assert executable == sys.argv[2]
    identity = (int(pid), start_time)
    assert identity not in seen, f"duplicate process identity {identity}"
    seen.add(identity)
    records.append({"pid": int(pid), "startTime": start_time, "executable": executable})
records.sort(key=lambda record: record["pid"])
print(json.dumps(records, separators=(",", ":"), sort_keys=True))
PY
}

fixture_processes() {
    local records status
    records="$(recorded_processes)"; status=$?
    (( status == 0 )) || return "$status"
    python3 - "$records" "$fixture_binary" <<'PY'
import json
import os
import pathlib
import sys

def live_identity(record):
    proc = pathlib.Path("/proc") / str(record["pid"])
    try:
        stat = (proc / "stat").read_text(encoding="utf-8")
    except FileNotFoundError:
        return None
    command_end = stat.rfind(")")
    assert command_end >= 0, f"malformed stat for pid {record['pid']}"
    fields = stat[command_end + 1:].split()
    assert len(fields) > 19, f"short stat for pid {record['pid']}"
    if fields[0] == "Z":
        return None
    start_time = fields[19]
    try:
        executable = os.readlink(proc / "exe")
    except FileNotFoundError:
        return None
    assert record["startTime"] == start_time, (
        f"pid {record['pid']} start time mismatch: recorded {record['startTime']}, live {start_time}"
    )
    assert record["executable"] == sys.argv[2]
    assert executable == sys.argv[2], (
        f"pid {record['pid']} executable mismatch: recorded {record['executable']}, live {executable}"
    )
    return record

live = []
for record in json.loads(sys.argv[1]):
    identity = live_identity(record)
    if identity is not None:
        live.append(identity)
print(json.dumps(live, separators=(",", ":"), sort_keys=True))
PY
}

# shellcheck disable=SC2329 # Called through the EXIT-trap cleanup chain.
validate_process_identity() {
    local pid="$1" start_time="$2" executable="$3"
    python3 - "$pid" "$start_time" "$executable" "$fixture_binary" <<'PY'
import os
import pathlib
import sys

pid = int(sys.argv[1])
proc = pathlib.Path("/proc") / str(pid)
try:
    stat = (proc / "stat").read_text(encoding="utf-8")
except FileNotFoundError:
    print("absent")
    raise SystemExit(0)
command_end = stat.rfind(")")
assert command_end >= 0
fields = stat[command_end + 1:].split()
assert len(fields) > 19
if fields[0] == "Z":
    print("absent")
    raise SystemExit(0)
start_time = fields[19]
try:
    executable = os.readlink(proc / "exe")
except FileNotFoundError:
    print("absent")
    raise SystemExit(0)
assert sys.argv[2] == start_time, (
    f"pid {pid} start time mismatch before signal: recorded {sys.argv[2]}, live {start_time}"
)
assert sys.argv[3] == sys.argv[4]
assert executable == sys.argv[4], (
    f"pid {pid} executable mismatch before signal: recorded {sys.argv[3]}, live {executable}"
)
print("live")
PY
}

# shellcheck disable=SC2329 # Called through the EXIT-trap cleanup chain.
terminate_fixture_processes() {
    local processes lines status pid start_time executable state i count
    processes="$(fixture_processes)"; status=$?
    (( status == 0 )) || return "$status"
    lines="$(python3 - "$processes" <<'PY'
import json
import sys
for record in json.loads(sys.argv[1]):
    print(f"{record['pid']}|{record['startTime']}|{record['executable']}")
PY
)"; status=$?
    (( status == 0 )) || return "$status"

    while IFS='|' read -r pid start_time executable; do
        [[ -n "$pid" ]] || continue
        state="$(validate_process_identity "$pid" "$start_time" "$executable")"; status=$?
        (( status == 0 )) || return "$status"
        if [[ "$state" == live ]]; then
            kill -TERM "$pid" || { echo "could not terminate validated fixture pid $pid" >&2; return 1; }
        elif [[ "$state" != absent ]]; then
            echo "unexpected fixture pid $pid validation state '$state'" >&2
            return 1
        fi
    done <<< "$lines"

    for ((i = 0; i < 40; i++)); do
        processes="$(fixture_processes)"; status=$?
        (( status == 0 )) || return "$status"
        count="$(json_array_count <<< "$processes")"; status=$?
        (( status == 0 )) || return "$status"
        [[ "$count" == 0 ]] && return 0
        sleep 0.25
    done
    echo "fixture processes survived termination: $processes" >&2
    return 1
}

# shellcheck disable=SC2329 # Registered by name in the EXIT trap.
cleanup() {
    local original_status=$? cleanup_failed=0 pid="" status=0 windows="" count=""
    trap - EXIT

    pid="$(read_dock_pid)"; status=$?
    if (( status != 0 )); then
        echo "FAIL: cleanup could not query the dock pid" >&2
        cleanup_failed=1
    elif kill -0 "$pid" 2>/dev/null; then
        if ! e2e_dock_stop; then
            echo "FAIL: cleanup could not stop dock pid $pid" >&2
            cleanup_failed=1
        fi
    fi
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
        echo "FAIL: cleanup left dock pid $pid running" >&2
        cleanup_failed=1
    fi

    if ! terminate_fixture_processes; then
        echo "FAIL: cleanup could not terminate validated fixture processes" >&2
        cleanup_failed=1
    fi
    windows="$(fixture_windows)"; status=$?
    if (( status != 0 )); then
        echo "FAIL: cleanup KWin fixture query failed with status $status" >&2
        cleanup_failed=1
    else
        count="$(json_array_count <<< "$windows")"; status=$?
        if (( status != 0 )) || [[ "$count" != 0 ]]; then
            echo "FAIL: cleanup left fixture windows: $windows" >&2
            cleanup_failed=1
        fi
    fi

    if [[ "$backup_ready" == true ]] && { ! cp "$backup" "$E2E_LAYOUT" || ! cmp -s "$backup" "$E2E_LAYOUT"; }; then
        echo "FAIL: cleanup could not byte-restore $E2E_LAYOUT" >&2
        cleanup_failed=1
    fi

    if ! rm -f "$fixture_desktop"; then
        echo "FAIL: cleanup could not remove fixture desktop $fixture_desktop" >&2
        cleanup_failed=1
    fi
    if ! kbuildsycoca6 --noincremental >/dev/null 2>&1; then
        echo "FAIL: cleanup could not refresh the KService cache" >&2
        cleanup_failed=1
    fi
    if ! rm -rf -- "$fixture_data"; then
        echo "FAIL: cleanup could not remove fixture data $fixture_data" >&2
        cleanup_failed=1
    fi
    for path in "$fixture_desktop" "$fixture_binary" "$fixture_record_log" "$fixture_data"; do
        if [[ -e "$path" ]]; then
            echo "FAIL: cleanup left fixture path $path" >&2
            cleanup_failed=1
        fi
    done
    for path in "${backup_prefix}"*; do
        [[ -e "$path" ]] || continue
        if ! rm -f -- "$path"; then
            echo "FAIL: cleanup could not remove backup $path" >&2
            cleanup_failed=1
        fi
    done
    for path in "${backup_prefix}"*; do
        if [[ -e "$path" ]]; then
            echo "FAIL: cleanup left backup path $path" >&2
            cleanup_failed=1
        fi
    done

    if [[ "$acceptance_completed" != true && $original_status -eq 0 ]]; then
        echo "FAIL: recipe exited before completing its acceptance" >&2
        original_status=1
    fi
    if (( cleanup_failed != 0 )); then
        if (( original_status != 0 )); then
            echo "FAIL: cleanup also failed after original recipe status $original_status" >&2
            exit "$original_status"
        fi
        exit 1
    fi
    if (( original_status != 0 )); then
        exit "$original_status"
    fi
    echo "PASS: SC-T5 middle-click dispatch and independent runtime effects"
    exit 0
}

inject() {
    local label="$1" status
    shift
    "$E2E_FAKEPOINTER" "$@"; status=$?
    (( status == 0 )) || e2e_fail "$label: fakepointer '$*' failed with status $status"
}

compile_fixture() {
    local compiler cflags_text libs_text status
    local -a cflags=() libs=()
    compiler="$(command -v c++)"; status=$?
    (( status == 0 )) && [[ -n "$compiler" ]] || e2e_fail "fixture C++ compiler is unavailable"
    cflags_text="$(pkg-config --cflags Qt6Widgets)"; status=$?
    (( status == 0 )) || e2e_fail "fixture Qt6Widgets compiler flags are unavailable"
    libs_text="$(pkg-config --libs Qt6Widgets)"; status=$?
    (( status == 0 )) || e2e_fail "fixture Qt6Widgets linker flags are unavailable"
    read -r -a cflags <<< "$cflags_text"
    read -r -a libs <<< "$libs_text"
    mkdir -p "$(dirname "$fixture_binary")" || e2e_fail "could not create the fixture binary directory"
    "$compiler" -std=c++20 -O2 "${cflags[@]}" "$fixture/window.cpp" -o "$fixture_binary" "${libs[@]}" \
        || e2e_fail "could not compile the SC-T5 fixture executable"
    [[ -x "$fixture_binary" ]] || e2e_fail "compiled fixture is not executable: $fixture_binary"
}

stage_desktop() {
    mkdir -p "$(dirname "$fixture_desktop")" || e2e_fail "could not create the fixture application directory"
    python3 - "$fixture/applications/$desktop_id" "$fixture_desktop" "$fixture_binary" <<'PY' \
        || e2e_fail "could not stage the fixture desktop service"
import pathlib
import sys

source = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
pathlib.Path(sys.argv[2]).write_text(source.replace("@BINARY@", sys.argv[3]), encoding="utf-8")
PY
    kbuildsycoca6 --noincremental >/dev/null 2>&1 \
        || e2e_fail "fixture desktop-service cache generation failed"
}

discover_task_fixture() {
    local status
    view="$(e2e_tasks_view)"; status=$?
    (( status == 0 )) && [[ -n "$view" ]] || e2e_fail "no tasks view"
    tasks_applet="$(e2e_json viewAppletsData u "$view" | python3 -c '
import json, sys
print(next(a["id"] for a in json.load(sys.stdin) if a["plugin"] == "org.kde.latte.plasmoid"))')"; status=$?
    (( status == 0 )) && [[ -n "$tasks_applet" ]] \
        || e2e_fail "could not resolve the tasks applet in view $view"
    config_group=(--file "$E2E_LAYOUT" --group Containments --group "$view" --group Applets --group "$tasks_applet" --group Configuration --group General)
    launchers_key="$(python3 - "$E2E_LAYOUT" "$view" "$tasks_applet" <<'PY'
import re
import sys

header = f"[Containments][{sys.argv[2]}][Applets][{sys.argv[3]}][Configuration][General]"
inside = False
for line in open(sys.argv[1], encoding="utf-8"):
    line = line.rstrip("\n")
    if line.startswith("["):
        inside = line == header
    elif inside and re.match(r"launchers[0-9]*=", line):
        print(line.split("=", 1)[0])
        break
PY
)"; status=$?
    (( status == 0 )) && [[ -n "$launchers_key" ]] \
        || e2e_fail "tasks applet $tasks_applet has no launcher-list key"
}

write_task_key() {
    local key="$1" value="$2" label="$3"
    kwriteconfig6 "${config_group[@]}" --key "$key" -- "$value" \
        || e2e_fail "$label: could not write $key=$value"
}

read_tasks() {
    local payload status
    payload="$(e2e_json viewTasksData u "$view")"; status=$?
    (( status == 0 )) || { echo "viewTasksData query failed with status $status" >&2; return "$status"; }
    python3 -c 'import json,sys; print(json.dumps(json.load(sys.stdin), separators=(",", ":"), sort_keys=True))' <<< "$payload"
}

read_dispatch() {
    local payload status
    payload="$(e2e_json taskMiddleClickDispatchData u "$view")"; status=$?
    (( status == 0 )) || { echo "taskMiddleClickDispatchData query failed with status $status" >&2; return "$status"; }
    python3 -c 'import json,sys; print(json.dumps(json.load(sys.stdin), separators=(",", ":"), sort_keys=True))' <<< "$payload"
}

running_config_snapshot() {
    local payload status
    payload="$(e2e_json appletConfigData uu "$view" "$tasks_applet")"; status=$?
    (( status == 0 )) || { echo "appletConfigData query failed with status $status" >&2; return "$status"; }
    python3 - "$payload" <<'PY'
import json
import sys

cfg = json.loads(sys.argv[1])["config"]
print(json.dumps({
    "groupTasksByDefault": cfg["groupTasksByDefault"],
    "hoverAction": cfg["hoverAction"],
    "middleClickAction": cfg["middleClickAction"],
}, separators=(",", ":"), sort_keys=True))
PY
}

configure_action() {
    local action="$1" label="$2" pid config status
    pid="$(read_dock_pid)"; status=$?
    (( status == 0 )) || e2e_fail "$label: dock pid query failed"
    kill -0 "$pid" 2>/dev/null || e2e_fail "$label: dock pid $pid is not running before configuration"
    e2e_dock_stop || e2e_fail "$label: could not stop dock pid $pid for configuration"
    if kill -0 "$pid" 2>/dev/null; then
        e2e_fail "$label: dock pid $pid survived configuration stop"
    fi

    write_task_key "$launchers_key" "$launcher_url" "$label"
    write_task_key middleClickAction "$action" "$label"
    write_task_key hoverAction 0 "$label"
    write_task_key animationLauncherBouncing false "$label"
    write_task_key animationNewWindowSliding false "$label"
    write_task_key animationWindowAddedInGroup false "$label"
    write_task_key groupTasksByDefault true "$label"
    write_task_key hideAllTasks false "$label"
    write_task_key showOnlyCurrentScreen false "$label"
    write_task_key showOnlyCurrentDesktop false "$label"
    write_task_key showOnlyCurrentActivity false "$label"
    write_task_key showWindowsOnlyFromLaunchers true "$label"
    kwriteconfig6 --file "$E2E_LAYOUT" --group Containments --group "$view" --group General --key alignment 1 \
        || e2e_fail "$label: could not set center alignment"
    kwriteconfig6 --file "$E2E_LAYOUT" --group Containments --group "$view" --group General --key alignmentUpgraded true \
        || e2e_fail "$label: could not mark alignment upgraded"

    e2e_dock_start 90 || e2e_fail "$label: dock did not settle"
    pid="$(read_dock_pid)"; status=$?
    if (( status != 0 )) || ! kill -0 "$pid" 2>/dev/null; then
        e2e_fail "$label: restarted dock pid is unavailable"
    fi
    config="$(running_config_snapshot)"; status=$?
    (( status == 0 )) || e2e_fail "$label: could not read the running config"
    python3 - "$config" "$action" <<'PY' \
        || e2e_fail "$label: running config does not match the fixture: $config"
import json
import sys

cfg = json.loads(sys.argv[1])
assert cfg == {
    "groupTasksByDefault": True,
    "hoverAction": 0,
    "middleClickAction": int(sys.argv[2]),
}
PY
    echo "SC_T5_OBSERVATION|phase=config|label=$label|json=$config"
}

model_matches() {
    local payload="$1" kind="$2"
    python3 - "$payload" "$kind" "$launcher_url" "$desktop_id" "$tasks_applet" <<'PY'
import json
import sys

rows = json.loads(sys.argv[1])
assert len(rows) == 1
row = rows[0]
assert row["launcherUrl"] == sys.argv[3]
assert row["appId"] == sys.argv[4]
assert row["appletId"] == int(sys.argv[5])
assert row["isMinimized"] is False
kind = sys.argv[2]
if kind == "launcher":
    assert row["isLauncher"] is True
    assert row["isGrouped"] is False
    assert row["childCount"] == 0
    assert row["isActive"] is False
elif kind == "single":
    assert row["isLauncher"] is False
    assert row["isGrouped"] is False
    assert row["childCount"] == 0
    assert row["isActive"] is True
elif kind == "group":
    assert row["isLauncher"] is False
    assert row["isGrouped"] is True
    assert row["childCount"] == 2
    assert row["isActive"] is True
else:
    raise AssertionError(f"unknown kind {kind}")
PY
}

runtime_snapshot_matches() {
    local windows="$1" processes="$2" tasks="$3" expected_windows="$4" kind="$5"
    model_matches "$tasks" "$kind" || return 1
    python3 - "$windows" "$processes" "$expected_windows" "$fixture_binary" <<'PY'
import json
import sys

windows = json.loads(sys.argv[1])
processes = json.loads(sys.argv[2])
expected = int(sys.argv[3])
assert len(windows) == len({window["id"] for window in windows}) == expected
assert len(processes) == len({
    (process["pid"], process["startTime"], process["executable"])
    for process in processes
}) == expected
assert sum(1 for window in windows if window["active"]) == (1 if expected else 0)
assert all(window["minimized"] is False for window in windows)
assert all(process["executable"] == sys.argv[4] for process in processes)
PY
}

wait_for_effect() {
    local expected_windows="$1" kind="$2" label="$3"
    local windows="" processes="" tasks="" window_count="" process_count="" all_windows="" status=0 i
    for ((i = 0; i < 60; i++)); do
        windows="$(fixture_windows)"; status=$?
        (( status == 0 )) || e2e_fail "$label: KWin query failed with status $status"
        processes="$(fixture_processes)"; status=$?
        (( status == 0 )) || e2e_fail "$label: process identity query failed with status $status"
        tasks="$(read_tasks)"; status=$?
        (( status == 0 )) || e2e_fail "$label: viewTasksData query failed with status $status"
        window_count="$(json_array_count <<< "$windows")"; status=$?
        (( status == 0 )) || e2e_fail "$label: KWin count parse failed"
        process_count="$(json_array_count <<< "$processes")"; status=$?
        (( status == 0 )) || e2e_fail "$label: process count parse failed"
        if [[ "$window_count" == "$expected_windows" && "$process_count" == "$expected_windows" ]] \
              && runtime_snapshot_matches "$windows" "$processes" "$tasks" "$expected_windows" "$kind" >/dev/null 2>&1
        then
            effect_windows="$windows"
            effect_processes="$processes"
            effect_tasks="$tasks"
            return 0
        fi
        sleep 0.25
    done
    all_windows="$(e2e_dumpwins)"; status=$?
    (( status == 0 )) || all_windows="KWin dump failed with status $status"
    e2e_fail "$label did not settle: windows=$windows processes=$processes tasks=$tasks allWindows=$all_windows"
}

phase_two_relation_matches() {
    local original_windows="$1" original_processes="$2" windows="$3" processes="$4" tasks="$5"
    model_matches "$tasks" group || return 1
    python3 - "$original_windows" "$original_processes" "$windows" "$processes" "$fixture_binary" <<'PY'
import json
import sys

original_windows = json.loads(sys.argv[1])
original_processes = json.loads(sys.argv[2])
windows = json.loads(sys.argv[3])
processes = json.loads(sys.argv[4])
assert len(original_windows) == len(original_processes) == 1
assert len(windows) == len({window["id"] for window in windows}) == 2
assert len(processes) == len({
    (process["pid"], process["startTime"], process["executable"])
    for process in processes
}) == 2

original_window = original_windows[0]
assert original_window["active"] is True
assert original_window["minimized"] is False
windows_by_id = {window["id"]: window for window in windows}
assert original_window["id"] in windows_by_id
persisted_window = windows_by_id[original_window["id"]]
assert persisted_window == {
    **original_window,
    "active": False,
    "minimized": False,
}
new_windows = [window for window in windows if window["id"] != original_window["id"]]
assert len(new_windows) == 1
assert new_windows[0]["active"] is True
assert new_windows[0]["minimized"] is False

original_process = original_processes[0]
assert original_process["executable"] == sys.argv[5]
process_identities = {
    (process["pid"], process["startTime"], process["executable"]): process
    for process in processes
}
original_identity = (
    original_process["pid"],
    original_process["startTime"],
    original_process["executable"],
)
assert original_identity in process_identities
new_processes = [
    process for process in processes
    if (process["pid"], process["startTime"], process["executable"]) != original_identity
]
assert len(new_processes) == 1
assert new_processes[0]["executable"] == sys.argv[5]
PY
}

wait_for_phase_two_effect() {
    local original_windows="$1" original_processes="$2" label="$3"
    local windows="" processes="" tasks="" all_windows="" status=0 i
    for ((i = 0; i < 60; i++)); do
        windows="$(fixture_windows)"; status=$?
        (( status == 0 )) || e2e_fail "$label: KWin query failed with status $status"
        processes="$(fixture_processes)"; status=$?
        (( status == 0 )) || e2e_fail "$label: process identity query failed with status $status"
        tasks="$(read_tasks)"; status=$?
        (( status == 0 )) || e2e_fail "$label: viewTasksData query failed with status $status"
        if phase_two_relation_matches "$original_windows" "$original_processes" "$windows" "$processes" "$tasks" >/dev/null 2>&1; then
            effect_windows="$windows"
            effect_processes="$processes"
            effect_tasks="$tasks"
            return 0
        fi
        sleep 0.25
    done
    all_windows="$(e2e_dumpwins)"; status=$?
    (( status == 0 )) || all_windows="KWin dump failed with status $status"
    e2e_fail "$label did not preserve one original and add exactly one new identity: windows=$windows processes=$processes tasks=$tasks allWindows=$all_windows"
}

assert_phase_two_relation_persists() {
    local original_windows="$1" original_processes="$2" label="$3"
    local windows processes tasks status
    windows="$(fixture_windows)"; status=$?
    (( status == 0 )) || e2e_fail "$label: KWin query failed with status $status"
    processes="$(fixture_processes)"; status=$?
    (( status == 0 )) || e2e_fail "$label: process identity query failed with status $status"
    tasks="$(read_tasks)"; status=$?
    (( status == 0 )) || e2e_fail "$label: viewTasksData query failed with status $status"
    phase_two_relation_matches "$original_windows" "$original_processes" "$windows" "$processes" "$tasks" \
        || e2e_fail "$label: old/new identity relation changed: windows=$windows processes=$processes tasks=$tasks"
    effect_windows="$windows"
    effect_processes="$processes"
    effect_tasks="$tasks"
}

locate_target_point() {
    local kind="$1" expected_windows="$2"
    local winx status views applets tasks windows processes
    winx="$(e2e_view_window_x "$view")"; status=$?
    (( status == 0 )) && [[ -n "$winx" ]] || { echo "could not resolve rendered x origin for view $view" >&2; return 1; }
    views="$(e2e_json viewsData)"; status=$?
    (( status == 0 )) || return "$status"
    applets="$(e2e_json viewAppletsData u "$view")"; status=$?
    (( status == 0 )) || return "$status"
    tasks="$(read_tasks)"; status=$?
    (( status == 0 )) || return "$status"
    windows="$(fixture_windows)"; status=$?
    (( status == 0 )) || return "$status"
    processes="$(fixture_processes)"; status=$?
    (( status == 0 )) || return "$status"
    if ! runtime_snapshot_matches "$windows" "$processes" "$tasks" "$expected_windows" "$kind"; then
        echo "target state is not exact $kind/$expected_windows: windows=$windows processes=$processes tasks=$tasks" >&2
        return 1
    fi
    printf '%s\n%s\n%s\n' "$views" "$applets" "$tasks" | python3 -c "
import json, sys
views, applets, tasks = (json.loads(line) for line in sys.stdin)
view = next(v for v in views if v['containmentId'] == $view)
applet = next(a for a in applets if a['id'] == $tasks_applet)
matches = [i for i, task in enumerate(tasks) if task['launcherUrl'] == '$launcher_url']
assert len(tasks) == 1 and matches == [0]
ax, ay = view['absoluteGeometry'][:2]
ly = view['localGeometry'][1]
px, py, pw, ph = applet['geometry']
assert pw > 0 and ph > 0
print(int($winx + px + pw / 2), int(ay - ly + py + ph / 2))
"
}

settle_target_pointer() {
    local label="$1" kind="$2" expected_windows="$3" point pointer_x pointer_y pass
    for pass in 1 2; do
        point="$(locate_target_point "$kind" "$expected_windows")" \
            || e2e_fail "$label: could not locate an exact $kind/$expected_windows target on settle pass $pass"
        read -r pointer_x pointer_y <<< "$point"
        [[ -n "$pointer_x" && -n "$pointer_y" ]] || e2e_fail "$label: target point is incomplete on settle pass $pass"
        inject "$label pointer exit pass $pass" move "$pointer_x" 500
        sleep 0.5
        inject "$label pointer glide pass $pass" glide "$pointer_x" 500 "$pointer_x" "$pointer_y"
        sleep 1.5
    done
    target_x="$pointer_x"
    target_y="$pointer_y"
}

capture_click_precondition() {
    local label="$1" kind="$2" expected_windows="$3" status
    pre_click_windows="$(fixture_windows)"; status=$?
    (( status == 0 )) || e2e_fail "$label: final pre-click KWin query failed with status $status"
    pre_click_processes="$(fixture_processes)"; status=$?
    (( status == 0 )) || e2e_fail "$label: final pre-click process query failed with status $status"
    pre_click_tasks="$(read_tasks)"; status=$?
    (( status == 0 )) || e2e_fail "$label: final pre-click task query failed with status $status"
    runtime_snapshot_matches "$pre_click_windows" "$pre_click_processes" "$pre_click_tasks" "$expected_windows" "$kind" \
        || e2e_fail "$label: final pre-click state is not exact $kind/$expected_windows: windows=$pre_click_windows processes=$pre_click_processes tasks=$pre_click_tasks"
}

dispatch_sequence() {
    python3 - "$1" <<'PY'
import json
import sys

record = json.loads(sys.argv[1])
sequence = record.get("sequence", 0)
assert isinstance(sequence, int)
print(sequence)
PY
}

assert_dispatch() {
    local payload="$1" row_kind="$2" action="$3" operation="$4" expected_sequence="$5"
    python3 - "$payload" "$row_kind" "$action" "$operation" "$launcher_url" "$expected_sequence" <<'PY'
import json
import sys

record = json.loads(sys.argv[1])
assert set(record) == {"configuredAction", "dispatchedOperation", "rowIdentity", "rowKind", "sequence"}
assert record["rowIdentity"] == sys.argv[5]
assert record["rowKind"] == sys.argv[2]
assert record["configuredAction"] == sys.argv[3]
assert record["dispatchedOperation"] == sys.argv[4]
assert record["sequence"] == int(sys.argv[6])
PY
}

drive_one_middle_click() {
    local label="$1" previous_sequence="$2" row_kind="$3" action="$4" operation="$5"
    local target_kind="$6" expected_windows="$7"
    local expected_sequence=$((previous_sequence + 1)) payload="" sequence=0 status=0 poll
    settle_target_pointer "$label" "$target_kind" "$expected_windows"
    capture_click_precondition "$label" "$target_kind" "$expected_windows"
    inject "$label" middleclick "$target_x" "$target_y"
    for ((poll = 0; poll < 40; poll++)); do
        payload="$(read_dispatch)"; status=$?
        (( status == 0 )) || e2e_fail "$label: taskMiddleClickDispatchData query failed with status $status"
        sequence="$(dispatch_sequence "$payload")"; status=$?
        (( status == 0 )) || e2e_fail "$label: invalid dispatch payload $payload"
        if (( sequence == previous_sequence )); then
            sleep 0.25
            continue
        fi
        (( sequence == expected_sequence )) \
            || e2e_fail "$label: sequence changed by more than one ($previous_sequence -> $sequence)"
        assert_dispatch "$payload" "$row_kind" "$action" "$operation" "$expected_sequence" \
            || e2e_fail "$label: unexpected dispatch after the one delivered click: $payload"
        observed_dispatch="$payload"
        observed_sequence="$sequence"
        return 0
    done
    e2e_fail "$label produced no dispatch after one status-0 middle click"
}

assert_dispatch_unchanged() {
    local expected_payload="$1" expected_sequence="$2" label="$3" payload sequence status
    payload="$(read_dispatch)"; status=$?
    (( status == 0 )) || e2e_fail "$label: taskMiddleClickDispatchData query failed with status $status"
    sequence="$(dispatch_sequence "$payload")"; status=$?
    (( status == 0 )) || e2e_fail "$label: invalid dispatch payload $payload"
    [[ "$payload" == "$expected_payload" && "$sequence" == "$expected_sequence" ]] \
        || e2e_fail "$label: dispatch changed after effect settlement: $payload"
}

assert_containment_isolation() {
    local payload status other views ids valid_controls=0
    views="$(e2e_json viewsData)"; status=$?
    (( status == 0 )) || e2e_fail "containment-isolation viewsData query failed with status $status"
    ids="$(python3 -c 'import json,sys; print("\n".join(str(v["containmentId"]) for v in json.load(sys.stdin)))' <<< "$views")"; status=$?
    (( status == 0 )) || e2e_fail "containment-isolation viewsData payload is invalid: $views"
    while read -r other; do
        [[ -n "$other" && "$other" != "$view" ]] || continue
        payload="$(e2e_json taskMiddleClickDispatchData u "$other")"; status=$?
        (( status == 0 )) || e2e_fail "containment-isolation query for view $other failed with status $status"
        [[ "$payload" == "{}" ]] || e2e_fail "target-view dispatch leaked into containment $other: $payload"
        valid_controls=$((valid_controls + 1))
    done <<< "$ids"
    payload="$(e2e_json taskMiddleClickDispatchData u 4294967295)"; status=$?
    (( status == 0 )) || e2e_fail "absent-containment isolation query failed with status $status"
    [[ "$payload" == "{}" ]] || e2e_fail "dispatch leaked into absent containment: $payload"
    echo "SC_T5_OBSERVATION|phase=containmentIsolation|validControls=$valid_controls|absentContainment=4294967295"
}

assert_no_effect_interval() {
    local expected_windows="$1" expected_processes="$2" expected_tasks="$3"
    local expected_dispatch="$4" expected_sequence="$5" label="$6"
    local windows processes tasks payload sequence status i
    for ((i = 0; i < 12; i++)); do
        sleep 0.25
        windows="$(fixture_windows)"; status=$?
        (( status == 0 )) || e2e_fail "$label: KWin query failed with status $status"
        processes="$(fixture_processes)"; status=$?
        (( status == 0 )) || e2e_fail "$label: process query failed with status $status"
        tasks="$(read_tasks)"; status=$?
        (( status == 0 )) || e2e_fail "$label: task query failed with status $status"
        payload="$(read_dispatch)"; status=$?
        (( status == 0 )) || e2e_fail "$label: dispatch query failed with status $status"
        sequence="$(dispatch_sequence "$payload")"; status=$?
        (( status == 0 )) || e2e_fail "$label: invalid dispatch payload $payload"
        [[ "$payload" == "$expected_dispatch" && "$sequence" == "$expected_sequence" ]] \
            || e2e_fail "$label: dispatch changed during no-op settlement: $payload"
        python3 - "$expected_windows" "$windows" "$expected_processes" "$processes" "$expected_tasks" "$tasks" <<'PY' \
            || e2e_fail "$label changed KWin, process, or task state"
import json
import sys

before_windows, after_windows = json.loads(sys.argv[1]), json.loads(sys.argv[2])
before_processes, after_processes = json.loads(sys.argv[3]), json.loads(sys.argv[4])
before_tasks, after_tasks = json.loads(sys.argv[5]), json.loads(sys.argv[6])
assert before_windows == after_windows
assert before_processes == after_processes
fields = ("appId", "appletId", "launcherUrl", "isLauncher", "isGrouped",
          "childCount", "isActive", "isMinimized")
assert len(before_tasks) == len(after_tasks) == 1
assert {field: before_tasks[0][field] for field in fields} == {
    field: after_tasks[0][field] for field in fields
}
PY
    done
    no_effect_windows="$windows"
    no_effect_processes="$processes"
    no_effect_tasks="$tasks"
}

# No command that can create fixture state runs outside this trap. The known
# prefix lets cleanup remove an allocation interrupted before assignment.
trap cleanup EXIT
backup="$(mktemp "${backup_prefix}XXXXXX")" || e2e_fail "could not allocate the layout backup"
cp "$E2E_LAYOUT" "$backup" || e2e_fail "could not back up $E2E_LAYOUT"
cmp -s "$E2E_LAYOUT" "$backup" || e2e_fail "layout backup differs immediately after copy"
backup_ready=true

discover_task_fixture
compile_fixture
stage_desktop

configure_action 2 "new-instance positive path"
initial_tasks="$(read_tasks)"; status=$?
(( status == 0 )) || e2e_fail "initial viewTasksData query failed with status $status"
model_matches "$initial_tasks" launcher \
    || e2e_fail "initial viewTasksData is not one pure fixture launcher: $initial_tasks"
initial_windows="$(fixture_windows)"; status=$?
(( status == 0 )) || e2e_fail "initial KWin query failed with status $status"
initial_processes="$(fixture_processes)"; status=$?
(( status == 0 )) || e2e_fail "initial process query failed with status $status"
initial_window_count="$(json_array_count <<< "$initial_windows")"; status=$?
(( status == 0 )) || e2e_fail "initial KWin count parse failed"
[[ "$initial_window_count" == 0 ]] || e2e_fail "fixture window exists before launcher input: $initial_windows"
initial_process_count="$(json_array_count <<< "$initial_processes")"; status=$?
(( status == 0 )) || e2e_fail "initial process count parse failed"
[[ "$initial_process_count" == 0 ]] || e2e_fail "fixture process exists before launcher input: $initial_processes"
initial_dispatch="$(read_dispatch)"; status=$?
(( status == 0 )) || e2e_fail "initial taskMiddleClickDispatchData query failed with status $status"
[[ "$initial_dispatch" == "{}" ]] || e2e_fail "fresh dock already has a middle-click dispatch: $initial_dispatch"
echo "SC_T5_OBSERVATION|phase=initial|windows=$initial_windows|processes=$initial_processes|tasks=$initial_tasks"

drive_one_middle_click "pure-launcher middle click" 0 launcher newInstance requestActivate launcher 0
launcher_sequence="$observed_sequence"
launcher_dispatch="$observed_dispatch"
assert_containment_isolation
wait_for_effect 1 single "launcher zero-to-one effect"
assert_dispatch_unchanged "$launcher_dispatch" 1 "launcher zero-to-one effect"
echo "SC_T5_OBSERVATION|phase=launcherDispatch|json=$launcher_dispatch"
echo "SC_T5_OBSERVATION|phase=launcherEffect|windows=$effect_windows|processes=$effect_processes|tasks=$effect_tasks"

drive_one_middle_click "single-window middle click" "$launcher_sequence" task newInstance requestNewInstance single 1
task_dispatch="$observed_dispatch"
phase_two_original_windows="$pre_click_windows"
phase_two_original_processes="$pre_click_processes"
phase_two_original_tasks="$pre_click_tasks"
assert_containment_isolation
wait_for_phase_two_effect "$phase_two_original_windows" "$phase_two_original_processes" "single-window one-to-two effect"
sleep 1
assert_dispatch_unchanged "$task_dispatch" 2 "single-window one-to-two effect"
assert_phase_two_relation_persists "$phase_two_original_windows" "$phase_two_original_processes" \
    "single-window one-to-two effect"
echo "SC_T5_OBSERVATION|phase=taskPreClick|windows=$phase_two_original_windows|processes=$phase_two_original_processes|tasks=$phase_two_original_tasks"
echo "SC_T5_OBSERVATION|phase=taskDispatch|json=$task_dispatch"
echo "SC_T5_OBSERVATION|phase=groupEffect|windows=$effect_windows|processes=$effect_processes|tasks=$effect_tasks"

configure_action 0 "offered-none negative control"
wait_for_effect 2 group "negative-control baseline"
negative_before_windows="$effect_windows"
negative_before_processes="$effect_processes"
negative_before_tasks="$effect_tasks"
initial_dispatch="$(read_dispatch)"; status=$?
(( status == 0 )) || e2e_fail "negative-control initial dispatch query failed with status $status"
[[ "$initial_dispatch" == "{}" ]] || e2e_fail "restarted dock did not reset to no-event state: $initial_dispatch"
drive_one_middle_click "offered-none middle click" 0 task none none group 2
negative_dispatch="$observed_dispatch"
[[ "$observed_sequence" == 1 ]] || e2e_fail "offered None sequence is not exactly 1: $observed_sequence"
assert_containment_isolation
assert_no_effect_interval "$negative_before_windows" "$negative_before_processes" "$negative_before_tasks" \
    "$negative_dispatch" 1 "offered-none no-op"
echo "SC_T5_OBSERVATION|phase=negativeDispatch|json=$negative_dispatch"
echo "SC_T5_OBSERVATION|phase=negativeNoEffect|windows=$no_effect_windows|processes=$no_effect_processes|tasks=$no_effect_tasks"

acceptance_completed=true
exit 0
