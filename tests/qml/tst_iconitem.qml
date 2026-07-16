/*
    SPDX-FileCopyrightText: 2026 Bree Spektor
    SPDX-FileCopyrightText: 2026 Latte Dock contributors
    SPDX-License-Identifier: GPL-2.0-or-later
*/

//! End-to-end companion of tests/units/iconsourceclassifiertest.cpp
//! (EX-24): drives the REAL shipped IconItem, resolved through the staged
//! org.kde.latte.core module, so the classifier's decisions are observed
//! through the C++ adapter and QML registration rather than in isolation.
//! Assertions stay on the deterministic surface - the local-file branch
//! against a shipped repo asset, the clear branch, and the
//! lastValidSourceName placeholder filter. Theme-name resolution success
//! (valid after source="firefox") depends on which icon themes the host
//! ships and is deliberately NOT asserted; whether resolved icons actually
//! render as pixels needs the live dock and stays on the pending live
//! check for this unit (docs/agent-logs/EX-24.md).

import QtQuick
import QtTest

import org.kde.latte.core 0.2 as LatteCore

TestCase {
    id: root
    name: "IconItemSourceRouting"

    //! a tiny image shipped with the plasmoid package: a stable in-repo
    //! target for the file:// branch, no fixture writing needed
    readonly property url localImage: Qt.resolvedUrl("../../plasmoid/package/contents/images/panel-west.png")

    Component {
        id: iconComponent
        LatteCore.IconItem {
            width: 24
            height: 24
        }
    }

    function test_localFileSourceLoadsAndIsRemembered() {
        var icon = createTemporaryObject(iconComponent, root);
        verify(icon);
        verify(!icon.valid, "a fresh IconItem must start with nothing resolved");

        //! string form, exactly as launcher configs deliver icon paths
        icon.source = localImage.toString();
        verify(icon.valid, "a file:// source pointing at a real image must resolve");
        compare(icon.lastValidSourceName, localImage.toString());
    }

    function test_clearedSourceInvalidates() {
        var icon = createTemporaryObject(iconComponent, root);
        verify(icon);

        icon.source = localImage.toString();
        verify(icon.valid);

        //! the Clear branch: an empty source resets every resolved member,
        //! but the last valid name survives (that is the property's job)
        icon.source = "";
        verify(!icon.valid, "an empty source must clear the resolved icon");
        compare(icon.lastValidSourceName, localImage.toString());
    }

    function test_placeholderNameIsNeverRemembered() {
        var icon = createTemporaryObject(iconComponent, root);
        verify(icon);
        compare(icon.lastValidSourceName, "");

        //! the application-x-executable placeholder a task shows while its
        //! real icon is unknown must never become the remembered name
        icon.source = "application-x-executable";
        compare(icon.lastValidSourceName, "");

        icon.source = localImage.toString();
        compare(icon.lastValidSourceName, localImage.toString());

        //! ...nor may it displace a real name recorded earlier
        icon.source = "application-x-executable";
        compare(icon.lastValidSourceName, localImage.toString());
    }
}
