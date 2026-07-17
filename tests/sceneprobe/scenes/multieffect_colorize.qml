// SPDX-FileCopyrightText: 2026 Latte Dock contributors
// SPDX-FileCopyrightText: 2026 Bree Spektor
// SPDX-License-Identifier: GPL-2.0-or-later
//
// MultiEffect colorization - the textColor tint used by TaskIcon badges and
// ParabolicItem's monochromizer. (The containment colorizer applet path is
// Qt5Compat ColorOverlay, NOT this shader - a flat-color-through-alpha scene
// for it is still owed, see the adoption plan's P1 scene list.) Shapes instead
// of the upstream scene's Text (unpinned font = latent cross-machine flake).
import QtQuick
import QtQuick.Effects

Item {
    width: 256; height: 256
    Rectangle {
        id: src
        anchors.fill: parent
        visible: false
        color: "darkorange"
        Rectangle { anchors.centerIn: parent; width: 96; height: 96; radius: 48; color: "white" }
    }
    MultiEffect {
        anchors.fill: parent
        source: src
        colorizationColor: "#3daee9"
        colorization: 0.8
    }
}
