/*
    SPDX-FileCopyrightText: 2026 Latte Dock contributors
    SPDX-FileCopyrightText: 2026 Bree Spektor
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid

PlasmoidItem {
    id: root

    Layout.minimumWidth: 48
    Layout.preferredWidth: 48
    Layout.maximumWidth: 48
    Layout.minimumHeight: 48
    Layout.preferredHeight: 48
    Layout.maximumHeight: 48

    Rectangle {
        anchors.centerIn: parent
        width: 28
        height: 28
        color: "#d62976"
        antialiasing: false
    }
}
