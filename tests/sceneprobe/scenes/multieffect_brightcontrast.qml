// SPDX-FileCopyrightText: 2026 Latte Dock contributors
// SPDX-FileCopyrightText: 2026 Bree Spektor
// SPDX-License-Identifier: GPL-2.0-or-later
//
// MultiEffect brightness+contrast - TaskIcon hover highlight (brightness 0.30,
// contrast 0.1). Shapes instead of the upstream scene's Text (unpinned font =
// latent cross-machine flake).
import QtQuick
import QtQuick.Effects

Item {
    width: 256; height: 256
    Rectangle {
        id: src
        anchors.fill: parent
        visible: false
        color: "seagreen"
        Rectangle { anchors.centerIn: parent; width: 96; height: 96; radius: 48; color: "white" }
    }
    MultiEffect {
        anchors.fill: parent
        source: src
        brightness: 0.30
        contrast: 0.1
    }
}
