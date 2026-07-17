// SPDX-FileCopyrightText: 2026 Latte Dock contributors
// SPDX-FileCopyrightText: 2026 Bree Spektor
// SPDX-License-Identifier: GPL-2.0-or-later
//
// Renders org.kde.graphicaleffects BadgeEffect - the masked-overlay
// ShaderEffect our TaskIcon.qml uses for task badges. Unlike ShadowedItem
// (precompiled MultiEffect), BadgeEffect is a real ShaderEffect that loads
// qrc:/shaders/badge.frag.qsb from kdeclarative at runtime, so this is the
// path that surfaces a "Failed to deserialize QShader" / "shader preparation
// failed" on the Vulkan RHI. source + mask are ShaderEffectSources, exactly
// as the call site wires them. Shapes instead of the upstream scene's Text
// (unpinned font = latent cross-machine flake).
import QtQuick
import org.kde.graphicaleffects as KGraphicalEffects

Item {
    width: 256; height: 256

    Rectangle {
        id: iconWidget
        anchors.fill: parent
        color: "steelblue"
        Rectangle { anchors.centerIn: parent; width: 120; height: 120; radius: 24; color: "white" }
    }

    Item {
        id: badgeMask
        anchors.fill: parent
        Rectangle {
            width: 40; height: 40; radius: 20
            x: parent.width - width; y: 0
            color: "white"
        }
    }

    KGraphicalEffects.BadgeEffect {
        anchors.fill: parent
        source: ShaderEffectSource {
            sourceItem: iconWidget
            hideSource: false
            live: false
        }
        mask: ShaderEffectSource {
            sourceItem: badgeMask
            hideSource: true
            live: false
        }
    }
}
