// SPDX-FileCopyrightText: 2026 Latte Dock contributors
// SPDX-FileCopyrightText: 2026 Bree Spektor
// SPDX-License-Identifier: GPL-2.0-or-later
//
// MultiEffect with no effect enabled - the bare copy path (CompactApplet,
// TaskIcon clickedAnimation effect). Loads the base MultiEffect shader
// variant. Shapes instead of the upstream scene's Text (unpinned font =
// latent cross-machine flake).
import QtQuick
import QtQuick.Effects

Item {
    width: 256; height: 256
    Rectangle {
        id: src
        anchors.fill: parent
        visible: false
        color: "slategray"
        Rectangle { anchors.centerIn: parent; width: 140; height: 56; radius: 12; color: "white" }
    }
    MultiEffect {
        anchors.fill: parent
        source: src
    }
}
