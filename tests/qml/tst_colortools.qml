/*
    SPDX-FileCopyrightText: 2026 Bree Spektor
    SPDX-FileCopyrightText: 2026 Latte Dock contributors
    SPDX-License-Identifier: GPL-2.0-or-later
*/

//! End-to-end companion of tests/units/colortoolstest.cpp (EX-19): drives
//! the REAL Tools singleton through the staged org.kde.latte.core module,
//! so QML registration and the invokable signatures are part of what is
//! exercised - this is the exact surface every cutover consumer (and any
//! third-party indicator package) calls. The expected values are rows of
//! the unit test's reference table, generated from the shipped
//! ColorizerTools.js before its deletion (generation method in the unit
//! test's header comment); comparisons are bit-exact on purpose, the JS
//! double semantics are the dedup contract.

import QtQuick
import QtTest

import org.kde.latte.core 0.2 as LatteCore

TestCase {
    id: root
    name: "ColorToolsSingleton"

    //! exact double equality; TestCase.compare() fuzzy-compares reals,
    //! which would defeat the bit-exactness contract
    function compareExact(actual, expected) {
        verify(actual === expected,
               "expected " + expected.toPrecision(17) + " got " + actual.toPrecision(17));
    }

    function test_brightnessMatchesTheDeletedJs_data() {
        return [
            { tag: "black", hex: "#000000", brightness: 0.0 },
            { tag: "white", hex: "#ffffff", brightness: 255.0 },
            { tag: "red", hex: "#ff0000", brightness: 76.245000000000005 },
            { tag: "grey127", hex: "#7f7f7f", brightness: 127.00000002980232 },
            { tag: "grey128", hex: "#808080", brightness: 128.00000756978989 },
            { tag: "capt-mixed", hex: "#ff8040", brightness: 158.67700487494469 },
        ];
    }

    function test_brightnessMatchesTheDeletedJs(data) {
        compareExact(LatteCore.Tools.colorBrightness(Qt.color(data.hex)), data.brightness);
    }

    function test_luminaMatchesTheDeletedJs_data() {
        return [
            { tag: "black", hex: "#000000", lumina: 0.0 },
            { tag: "white", hex: "#ffffff", lumina: 1.0 },
            { tag: "linear-branch", hex: "#0a0a0a", lumina: 0.003035269942907357 },
            { tag: "power-branch", hex: "#0b0b0b", lumina: 0.0033465358583530469 },
            { tag: "capt-purple", hex: "#7b2dc8", lumina: 0.10257856962031991 },
        ];
    }

    function test_luminaMatchesTheDeletedJs(data) {
        compareExact(LatteCore.Tools.colorLumina(Qt.color(data.hex)), data.lumina);
    }

    function test_isLightSplitsAtTheInheritedMidpoint() {
        //! the tree-wide strictly-greater 127.5 split (Manager.qml's
        //! editModeTextColorIsBright consumes this exact call)
        verify(!LatteCore.Tools.isLight(Qt.color("#7f7f7f")));
        verify(LatteCore.Tools.isLight(Qt.color("#808080")));

        //! explicit threshold overload, strictness pinned at white's exact 255
        verify(!LatteCore.Tools.isLight(Qt.color("#808080"), 200.0));
        verify(!LatteCore.Tools.isLight(Qt.color("#ffffff"), 255.0));
        verify(LatteCore.Tools.isLight(Qt.color("#ffffff"), 254.9));
    }
}
