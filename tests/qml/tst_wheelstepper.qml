/*
    SPDX-FileCopyrightText: 2026 Bree Spektor
    SPDX-FileCopyrightText: 2026 Latte Dock contributors
    SPDX-License-Identifier: GPL-2.0-or-later
*/

//! Drives the REAL registered LatteCore.WheelStepper (EX-15) through the
//! staged install: module registration, enum export, REQUIRED axisPick
//! enforcement and the two firing modes as QML sees them. The semantic
//! depth lives in tests/units/wheelaccumulatortest.cpp; this is the
//! boundary's e2e layer.

import QtQuick 2.7
import QtTest 1.2

import org.kde.latte.core 0.2 as LatteCore

Item {
    id: root

    LatteCore.WheelStepper {
        id: audioStepper
        axisPick: LatteCore.WheelStepper.VerticalElseNegatedHorizontal
        stepSize: 120
        resetOnReversal: true
    }

    LatteCore.WheelStepper {
        id: rulerStepper
        axisPick: LatteCore.WheelStepper.VerticalOnly
        fireThreshold: 96
    }

    Component {
        id: axislessStepper
        LatteCore.WheelStepper {
            stepSize: 120
        }
    }

    TestCase {
        name: "WheelStepper"

        function test_accumulatingModeThroughTheRealEngine() {
            compare(audioStepper.add(Qt.point(0, 360), false), 3);
            compare(audioStepper.add(Qt.point(0, 90), false), 0);
            compare(audioStepper.add(Qt.point(0, -30), false), 0); // reversal reset
            compare(audioStepper.add(Qt.point(0, -90), false), -1);
            compare(audioStepper.add(Qt.point(0, 120), true), -1); // inverted
            compare(audioStepper.add(Qt.point(120, 0), false), -1); // negated horizontal fallback
        }

        function test_thresholdModeThroughTheRealEngine() {
            compare(rulerStepper.add(Qt.point(0, 96), false), 0); // strict >
            compare(rulerStepper.add(Qt.point(0, 97), false), 1);
            compare(rulerStepper.add(Qt.point(960, -97), false), -1); // horizontal ignored
        }

        function test_requiredAxisPickRefusesInstantiation() {
            ignoreWarning(new RegExp(".*[Rr]equired property axisPick was not initialized.*"));
            var created = axislessStepper.createObject(root);
            verify(created === null,
                   "an axis-less stepper must not instantiate (axisPick is REQUIRED)");
        }
    }
}
