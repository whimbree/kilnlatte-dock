// SPDX-FileCopyrightText: 2026 Latte Dock contributors
// SPDX-License-Identifier: GPL-2.0-or-later
//
// Known-bad scene: must FAIL the shader gate, or the gate itself is broken.
import QtQuick

Item {
    width: 256; height: 256
    ShaderEffect {
        anchors.fill: parent
        // Points at a .qsb that does not exist -> "shader preparation failed".
        fragmentShader: "file:///nonexistent/definitely-missing.frag.qsb"
    }
}
