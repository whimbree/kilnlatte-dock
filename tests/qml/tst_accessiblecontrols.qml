/*
    SPDX-FileCopyrightText: 2026 Bree Spektor
    SPDX-FileCopyrightText: 2026 Latte Dock contributors
    SPDX-License-Identifier: GPL-2.0-or-later
*/

//! Pins the screen-reader surface of the settings windows' hand-rolled
//! controls (Phase 10 AT-SPI rollout) against the REAL shipped
//! org.kde.latte.components module: HeaderSwitch's ghost-button checkbox
//! (the a11y-surface inventory's named gap - an Item root whose real
//! Switch sits under an invisible ghost, so nothing announced) and
//! ComboBoxButton (Rectangle root whose checkable variant blanks the
//! button text). Reads the Accessible attached properties off the
//! instantiated components and drives the press action through the same
//! item.pressed() signal the mouse path raises.

import QtQuick
import QtTest

import org.kde.latte.components 1.0 as LatteComponents

Item {
    id: root
    width: 500
    height: 300

    property int headerPressedCount: 0

    LatteComponents.HeaderSwitch {
        id: headerSwitch
        width: 300
        text: "Background"
        tooltip: "Enable background"
        checked: true
        onPressed: root.headerPressedCount = root.headerPressedCount + 1
    }

    LatteComponents.ComboBoxButton {
        id: comboButton
        width: 300
        height: 30
        checkable: true
        buttonText: "Apply Layout"
        buttonToolTip: "Apply the selected layout"
    }

    TestCase {
        name: "AccessibleControls"
        when: windowShown

        function ghost() {
            return findChild(headerSwitch, "switchToggleGhost");
        }

        function test_headerSwitchGhostAnnouncesTheHeader() {
            var toggle = ghost();
            verify(toggle !== null, "the switch ghost is reachable");

            compare(toggle.Accessible.role, Accessible.CheckBox,
                    "the ghost announces as a checkbox");
            compare(toggle.Accessible.name, "Background",
                    "the ghost carries the visible header text as its name");
            compare(toggle.Accessible.description, "Enable background",
                    "the tooltip rides along as the description");
            verify(toggle.Accessible.checkable, "checkable state is exposed");
            compare(toggle.Accessible.checked, true,
                    "checked mirrors the switch");

            headerSwitch.checked = false;
            compare(toggle.Accessible.checked, false,
                    "checked tracks live state changes");
        }

        function test_headerSwitchPressActionRaisesTheSameSignal() {
            var toggle = ghost();
            verify(toggle !== null, "the switch ghost is reachable");

            var before = root.headerPressedCount;
            toggle.Accessible.pressAction();
            compare(root.headerPressedCount, before + 1,
                    "the a11y press raises item.pressed() exactly like a click");

            toggle.Accessible.toggleAction();
            compare(root.headerPressedCount, before + 2,
                    "the a11y toggle raises the same signal");
        }

        function test_comboBoxButtonNamesBothHalves() {
            //! the checkable variant blanks the real button text (a Label
            //! overlays it), which without the explicit names would leave
            //! an accessible name of " "
            compare(comboButton.button.text, " ",
                    "precondition: checkable variant blanks the button text");
            compare(comboButton.button.Accessible.name, "Apply Layout",
                    "the button half announces the visible label");
            compare(comboButton.button.Accessible.description, "Apply the selected layout",
                    "the tooltip rides along as the description");
            compare(comboButton.comboBox.Accessible.name, "Apply Layout",
                    "the combobox half shares the chip's label (its display text is hidden)");
        }
    }
}
