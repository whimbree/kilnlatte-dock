// SPDX-FileCopyrightText: 2026 Latte Dock contributors
// SPDX-License-Identifier: GPL-2.0-or-later
//
// Known-good scene: must PASS, or the gate itself is broken (exit 3).
import QtQuick

Rectangle {
    width: 256; height: 256
    color: "steelblue"
    Rectangle { anchors.centerIn: parent; width: 80; height: 80; radius: 12; color: "white" }
}
