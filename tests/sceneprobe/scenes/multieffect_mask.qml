// SPDX-FileCopyrightText: 2026 Latte Dock contributors
// SPDX-FileCopyrightText: 2026 Bree Spektor
// SPDX-License-Identifier: GPL-2.0-or-later
//
// MultiEffect mask - the layer.effect opacity mask the plasmoid uses to fade
// scrolled tasks (main.qml, ScrollOpacityMask) and the tooltip player-controls
// mask. maskSource is a layer-backed texture provider, exactly as the call
// sites wire it. Shapes instead of the upstream scene's Text (unpinned font =
// latent cross-machine flake).
import QtQuick
import QtQuick.Effects

Item {
    width: 256; height: 256
    Rectangle {
        id: src
        anchors.fill: parent
        visible: false
        color: "teal"
        Rectangle { anchors.centerIn: parent; width: 140; height: 56; radius: 12; color: "white" }
    }
    Item {
        id: maskSrc
        anchors.fill: parent
        layer.enabled: true
        visible: false
        Rectangle { anchors.centerIn: parent; width: 160; height: 160; radius: 80; color: "white" }
    }
    MultiEffect {
        anchors.fill: parent
        source: src
        maskEnabled: true
        maskSource: maskSrc
        maskThresholdMin: 0.0
        maskSpreadAtMin: 1.0
        autoPaddingEnabled: false
    }
}
