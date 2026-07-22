/*
    SPDX-FileCopyrightText: 2026 Bree Spektor
    SPDX-FileCopyrightText: 2026 Latte Dock contributors
    SPDX-License-Identifier: GPL-2.0-or-later
*/

//! Pins the add-widgets chrome's screen-reader surface (Phase 10 AT-SPI
//! rollout) against the REAL shipped AppletDelegate.qml, instantiated as a
//! GridView delegate exactly as WidgetExplorer.qml hosts it. Context
//! plumbing mirrors production: the ids the delegate resolves through the
//! creation-context chain (main, widgetExplorer, pendingUninstallTimer,
//! list) are provided here with recorder shims, and the model roles arrive
//! through a real delegate context over a ListModel. Asserts the card's
//! role/name/description, the current-item focus mirror, and that the
//! Accessible press action lands in the same page-level addApplet()
//! call the tap runs.

import QtQuick
import QtTest

import "../../shell/package/contents/views" as ShellViews

Item {
    id: root
    width: 600
    height: 500

    //! creation-context shims for the ids AppletDelegate resolves
    Item {
        id: main
        property bool draggingWidget: false
        property int refreshRequests: 0
        property var addedApplets: []
        function addApplet(pluginName) { addedApplets.push(pluginName); }
        function runningInstancesFor(pluginName) { return 0; }
        function scheduleRunningCountRefresh() { refreshRequests = refreshRequests + 1; }
    }

    Item {
        id: widgetExplorer
        function removeAllInstances(pluginName) { }
    }

    Timer {
        id: pendingUninstallTimer
        property var applets: []
    }

    GridView {
        id: list
        anchors.fill: parent
        cellWidth: 190
        cellHeight: 240
        currentIndex: 0

        model: ListModel {
            id: widgetsModel
            Component.onCompleted: {
                append({ pluginName: "org.kde.plasma.clock",
                         name: "Analog Clock",
                         description: "A clock with hands",
                         decoration: "",
                         screenshot: "",
                         local: false,
                         recent: false });
                append({ pluginName: "org.kde.plasma.notes",
                         name: "Notes",
                         description: "Desktop sticky notes",
                         decoration: "",
                         screenshot: "",
                         local: false,
                         recent: false });
            }
        }

        delegate: ShellViews.AppletDelegate {}
    }

    TestCase {
        name: "AddWidgetsAccessible"
        when: windowShown

        function card(row) {
            list.forceLayout();
            return list.itemAtIndex(row);
        }

        function test_cardAnnouncesTheWidget() {
            var clock = card(0);
            verify(clock !== null, "the first delegate instantiates");

            compare(clock.Accessible.role, Accessible.Button,
                    "the card announces as a button");
            compare(clock.Accessible.name, "Analog Clock",
                    "name is the widget's visible title");
            compare(clock.Accessible.description, "A clock with hands",
                    "description is the widget's visible description");
        }

        function test_focusedFollowsTheGridCurrentItem() {
            var clock = card(0);
            var notes = card(1);
            verify(clock !== null && notes !== null, "both delegates instantiate");

            list.currentIndex = 0;
            compare(clock.Accessible.focused, true, "current item reports focused");
            compare(notes.Accessible.focused, false, "non-current item does not");

            list.currentIndex = 1;
            compare(clock.Accessible.focused, false, "focus mirror moves away");
            compare(notes.Accessible.focused, true, "focus mirror follows currentIndex");
        }

        function test_pressActionAddsTheWidgetLikeATap() {
            var notes = card(1);
            verify(notes !== null, "the second delegate instantiates");

            var addsBefore = main.addedApplets.length;
            var refreshesBefore = main.refreshRequests;

            notes.Accessible.pressAction();

            compare(main.addedApplets.length, addsBefore + 1,
                    "the a11y press adds exactly one widget");
            compare(main.addedApplets[main.addedApplets.length - 1],
                    "org.kde.plasma.notes",
                    "the added plugin is this card's");
            compare(main.refreshRequests, refreshesBefore + 1,
                    "the running-count refresh rides along, same as a tap");
        }
    }
}
