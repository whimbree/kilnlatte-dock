/*
    SPDX-FileCopyrightText: 2020 Aleix Pol Gonzalez <aleixpol@kde.org>
    SPDX-License-Identifier: LGPL-2.0-or-later
*/

import QtQuick

import org.kde.pipewire as PipeWire
import org.kde.taskmanager as TaskManager

//! Plasma 6 shape of the wayland window preview, taken from plasma-desktop's
//! taskmanager PipeWireThumbnail.qml: PipeWireSourceItem is the root and
//! manages its own enabled state. The old 5.26-era variant kept
//! `enabled: false` relying on kpipewire 5 to flip it from C++; kpipewire 6
//! does not, so opacity stayed 0 and previews always fell back to the icon.
PipeWire.PipeWireSourceItem {
    id: pipeWireSourceItem

    readonly property alias hasThumbnail: pipeWireSourceItem.ready

    anchors.fill: parent
    visible: waylandItem.nodeId > 0
    nodeId: waylandItem.nodeId

    TaskManager.ScreencastingRequest {
        id: waylandItem
        //! Latte's previews dialog persists while hidden (upstream destroys its
        //! tooltip), so stop the screencast stream whenever it is not visible.
        uuid: windowsPreviewDlg.visible ? thumbnailSourceItem.winId : ""
    }
}
