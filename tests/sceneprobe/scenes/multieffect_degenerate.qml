// SPDX-FileCopyrightText: 2026 Latte Dock contributors
// SPDX-FileCopyrightText: 2026 Bree Spektor
// SPDX-License-Identifier: GPL-2.0-or-later
//
// Degenerate MultiEffect parameters - shadowBlur animates from 0.0 to 0.8
// across the 5 rendered frames (the fixed-step clock makes the sweep
// deterministic). This exercises the edge where the blur shader transitions
// out of its zero/disabled state; any transient NaN or shader compilation
// failure on an intermediate frame trips the gate. The final frame is
// non-blank (shadowEnabled draws the spread even at shadowBlur=0), so the
// output floor also validates. Shapes instead of the upstream scene's Text
// (unpinned font = latent cross-machine flake).
import QtQuick
import QtQuick.Effects

Item {
    width: 256; height: 256
    property var probeExpect: [ { "minOpaqueFraction": 0.05 } ]

    Rectangle {
        id: src
        anchors.centerIn: parent
        width: 120; height: 120
        radius: 16
        color: "seagreen"
        Rectangle { anchors.centerIn: parent; width: 48; height: 48; radius: 24; color: "white" }
    }

    MultiEffect {
        anchors.fill: src
        source: src
        // autoPadding is BANNED in shipped QML (qml-effect-rules.sh, family 7:
        // it re-dirties the effect every frame). This scene is not shipped -
        // it deliberately drives the degenerate animated-autopadding path the
        // ban exists for, so a Qt regression there still gets caught.
        autoPaddingEnabled: true
        shadowEnabled: true
        shadowColor: Qt.rgba(0, 0, 0, 0.8)
        blurMax: 32
        NumberAnimation on shadowBlur {
            from: 0.0; to: 0.8
            duration: 80
            running: true
        }
    }
}
