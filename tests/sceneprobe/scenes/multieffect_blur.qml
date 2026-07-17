// SPDX-FileCopyrightText: 2026 Latte Dock contributors
// SPDX-FileCopyrightText: 2026 Bree Spektor
// SPDX-License-Identifier: GPL-2.0-or-later
//
// MultiEffect blur - ToolTipInstance album-art frosted background (blurEnabled,
// blur 1.0, blurMax 32). The blur path is a separate multi-pass shader set from
// the colour effects. Shapes instead of the upstream scene's Text: an unpinned
// font family is a latent cross-machine flake (adoption doc P1 note), and the
// blur shaders do not care what they blur.
import QtQuick
import QtQuick.Effects

Item {
    width: 256; height: 256
    Rectangle {
        id: src
        anchors.fill: parent
        visible: false
        gradient: Gradient { GradientStop { position: 0; color: "purple" } GradientStop { position: 1; color: "gold" } }
        Rectangle { anchors.centerIn: parent; width: 120; height: 48; radius: 24; color: "white" }
    }
    MultiEffect {
        anchors.fill: parent
        source: src
        blurEnabled: true
        blur: 1.0
        blurMax: 32
        autoPaddingEnabled: false
    }
}
