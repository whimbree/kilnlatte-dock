/*
    SPDX-FileCopyrightText: 2019 Michail Vourlakos <mvourlakos@gmail.com>
    SPDX-FileCopyrightText: 2026 Bree Spektor
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick 2.0

import org.kde.plasma.plasmoid 2.0

import org.kde.latte.private.tasks 0.1 as LatteTasks

//! Trying to WORKAROUND all the Plasma LibTaskManager limitations
//! concerning Tasks AND Launchers.
//!
//! Plasma LibTaskManager constantly creates ADDITIONS/REMOVALS when
//! a Task is changing its type from Launcher<->Startup<->Window.
//! This libtaskmanager behavior limits a lot the animations that
//! can be created in order to provide a moder user experience
//!
//! All the logic that is trying to improve the mentioned limits is provided
//! from this class
//!
//! EX-11: registry membership lives in the TasksExtendedRegistries C++
//! shell (units/launcherlistops.h owns the semantics); this file keeps the
//! state machine around it - the paused-state count latches, the signals,
//! and the three timers.

Item {
    id: tasksExtManager

    //! injected at the instantiation site (main.qml), so the reads below
    //! stay off the context chain (QtObject deliberately: only signals and
    //! functions are consumed, and the offscreen harness injects a plain
    //! QtObject stand-in)
    property QtObject launchersAbility: null
    property QtObject tasksModel: null

    readonly property int launchersInPausedStateCount: launchersToBeMovedCount + launchersToBeAddedCount + launchersToBeRemovedCount

    property int launchersToBeMovedCount: 0 //is used to update instantly relevant bindings
    property int launchersToBeAddedCount: 0 //is used to update instantly relevant bindings
    property int launchersToBeRemovedCount: 0 //is used to update instantly relevant bindings

    signal waitingLauncherRemoved(string launch);

    LatteTasks.TasksExtendedRegistries {
        id: registries
    }

    /////////// FUNCTIONALITY ////////////////////

    /// WAITING LAUNCHERS: launchers that are playing an ADD or REMOVAL
    /// animation and their Startups/Windows should be aware of
    function addWaitingLauncher(launch){
        arraysGarbageCollectorTimer.restart();
        registries.addWaiting(launch);
    }

    function removeWaitingLauncher(launch){
        if (registries.removeWaiting(launch)) {
            tasksExtManager.waitingLauncherRemoved(launch);
        }
    }

    function waitingLauncherExists(launch){
        return registries.waitingExists(launch);
    }

    function waitingLaunchersLength() {
        return registries.waitingCount();
    }

    function printWaitingLaunchers() {
        console.log("WAITING LAUNCHERS ::: " + registries.waitingItems());
    }

    //! LAUNCHERSTOBEADDED: launchers that are added from user actions. They
    //! can be used in order to provide addition animations properly
    function addToBeAddedLauncher(launcher){
        arraysGarbageCollectorTimer.restart();

        if (registries.addToBeAdded(launcher)) {
            tasksExtManager.launchersToBeAddedCount++;
        }
    }

    function removeToBeAddedLauncher(launcher){
        if (registries.removeToBeAdded(launcher)) {
            tasksExtManager.launchersToBeAddedCount--;
        }
    }

    function toBeAddedLauncherExists(launcher) {
        return registries.toBeAddedExists(launcher);
    }

    function printToBeAddedLaunchers() {
        console.log("TO BE ADDED LAUNCHERS ::: " + registries.toBeAddedItems());
    }

    //! LAUNCHERSTOBEREMOVED: launchers that are removed from user actions.
    //! They can be used in order to provide removal animations properly
    function addToBeRemovedLauncher(launcher){
        arraysGarbageCollectorTimer.restart();

        if (registries.addToBeRemoved(launcher)) {
            tasksExtManager.launchersToBeRemovedCount++;
        }
    }

    function removeToBeRemovedLauncher(launcher){
        if (registries.removeToBeRemoved(launcher)) {
            tasksExtManager.launchersToBeRemovedCount--;
        }
    }

    function isLauncherToBeRemoved(launcher) {
        return registries.toBeRemovedExists(launcher);
    }

    function printToBeRemovedLaunchers() {
        console.log("TO BE REMOVED LAUNCHERS ::: " + registries.toBeRemovedItems());
    }

    //! IMMEDIATELAUNCHERS: launchers that must be shown IMMEDIATELY after a
    //! window removal because they are already present from a present
    //! libtaskmanager state
    function addImmediateLauncher(launch){
        arraysGarbageCollectorTimer.restart();
        registries.addImmediate(launch);
    }

    function removeImmediateLauncher(launch){
        registries.removeImmediate(launch);
    }

    function immediateLauncherExists(launch){
        return registries.immediateExists(launch);
    }

    function printImmediateLaunchers() {
        console.log("IMMEDIATE LAUNCHERS ::: " + registries.immediateItems());
    }

    //! FROZENTASKS: tasks that change state (launcher,startup,window) and
    //! at the next state must look the same concerning the parabolic effect
    function getFrozenTask(identifier) {
        var zoom = registries.frozenZoom(identifier);
        return zoom === undefined ? undefined : { id: identifier, zoom: zoom };
    }

    function removeFrozenTask(identifier) {
        registries.removeFrozenZoom(identifier);
    }

    function setFrozenTask(identifier, scale) {
        arraysGarbageCollectorTimer.restart();
        registries.setFrozenZoom(identifier, scale);
    }

    function printFrozenTasks() {
        console.log("FROZEN TASKS ::: " + JSON.stringify(registries.frozenEntries()));
    }

    //! LAUNCHERSTOBEMOVED: new launchers to have been added and must be
    //! repositioned to their intended place
    function addLauncherToBeMoved(launcherUrl, toPos) {
        arraysGarbageCollectorTimer.restart();

        if (registries.addMoveIntent(launcherUrl, toPos)) {
            tasksExtManager.launchersToBeMovedCount++;
        }
    }

    function moveLauncherToCorrectPos(launcherUrl, from) {
        //! consumes the intent atomically (the Qt5 get-then-remove pair)
        var to = registries.takeMoveIntentPosition(launcherUrl);

        if (to !== undefined) {
            launchersToBeMovedTimer.from = from;
            launchersToBeMovedTimer.to = to;
            launchersToBeMovedTimer.launcherUrl = launcherUrl;
            launchersToBeMovedTimer.start();
        }
    }

    function isLauncherToBeMoved(launcher) {
        return registries.moveIntentExists(launcher);
    }

    function printToBeMovedLaunchers() {
        console.log("TO BE MOVED LAUNCHERS ::: " + JSON.stringify(registries.moveIntents()));
    }

    //! the GC sweep body; also the reset seam tests/qml/tst_launcherlistops.qml drives
    function clearRegistries() {
        registries.clearAll();

        //! clear up launchers counters
        tasksExtManager.launchersToBeMovedCount = 0;
        tasksExtManager.launchersToBeAddedCount = 0;
        tasksExtManager.launchersToBeRemovedCount = 0;
    }

    //! Connections
    Connections {
        target: tasksExtManager.launchersAbility
        function onLauncherInRemoving(launcherUrl) { tasksExtManager.addToBeRemovedLauncher(launcherUrl); }
        function onLauncherInAdding(launcherUrl) { tasksExtManager.addToBeAddedLauncher(launcherUrl); }
        function onLauncherInMoving(launcherUrl, pos) { tasksExtManager.addLauncherToBeMoved(launcherUrl, pos); }
    }


    //!Trying to avoid a binding loop in TaskItem for modelLauncherUrl
    Timer {
        id: launchersToBeMovedTimer
        interval: 50
        property int from: -1
        property int to: -1

        property string launcherUrl: ""

        onTriggered: {
            tasksExtManager.tasksModel.move(from, to);
            delayedLaynchersSyncTimer.start();
        }
    }

    //! delay a bit  the launchers syncing in order to avoid a crash
    //! the crash was caused from TasksExtendedManager when adding and moving a launcher (e.g. internal separator)
    //! and there were more than one synced docks
    Timer {
        id: delayedLaynchersSyncTimer
        interval: 450
        onTriggered: {
            tasksExtManager.tasksModel.syncLaunchers();
            tasksExtManager.launchersAbility.validateSyncedLaunchersOrder();
            //! In case there are multiple launchers in moving state
            tasksExtManager.launchersToBeMovedCount = 0;
        }
    }


    //! Timer to clean up all registries used from TasksExtendedManager after a specified interval
    //! The registries may have ghost records that were not used from animations or other plasmoid parts.
    //! Each record is usually only a matter of secs to be used, cleaning them after
    //! a big interval from the last addition it is safe
    Timer {
        id: arraysGarbageCollectorTimer
        interval: 30 * 1000
        onTriggered: {
            console.log(" TASKS EXTENDED MANAGER Garbage Collector...");
            tasksExtManager.printImmediateLaunchers();
            tasksExtManager.printToBeAddedLaunchers();
            tasksExtManager.printToBeMovedLaunchers();
            tasksExtManager.printToBeRemovedLaunchers();
            tasksExtManager.printWaitingLaunchers();
            tasksExtManager.printFrozenTasks();

            tasksExtManager.clearRegistries();
        }
    }
}
