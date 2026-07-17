// SPDX-FileCopyrightText: 2026 Latte Dock contributors
// SPDX-FileCopyrightText: 2026 Bree Spektor
// SPDX-License-Identifier: GPL-2.0-or-later
//
// MultiEffect saturation:-1 - the grayscale path (TaskIcon stateColorizer /
// badge desaturate, RemoveWindowFromGroupAnimation). Loads the saturation
// shader variant. Shapes instead of the upstream scene's Text (unpinned font
// = latent cross-machine flake).
import QtQuick
import QtQuick.Effects

Item {
    width: 256; height: 256
    Rectangle {
        id: src
        anchors.fill: parent
        visible: false
        gradient: Gradient { GradientStop { position: 0; color: "tomato" } GradientStop { position: 1; color: "royalblue" } }
        Rectangle { anchors.centerIn: parent; width: 96; height: 96; radius: 48; color: "white" }
    }
    MultiEffect {
        anchors.fill: parent
        source: src
        saturation: -1
    }
}
