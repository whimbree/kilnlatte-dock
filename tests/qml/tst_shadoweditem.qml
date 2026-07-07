/*
    SPDX-FileCopyrightText: 2026 Bree Spektor
    SPDX-License-Identifier: GPL-2.0-or-later
*/

//! First occupant of the headless QML interaction harness (docs/TESTING.md).
//! ShadowedItem is resolved through the real module import, not a file URL:
//! latte-dock-qt6 shipped an unresolved "LatteComponents.ShadowedItem is not
//! a type" bug with exactly this component, so type resolution through the
//! installed module is itself the contract under test here, alongside the
//! px-radius -> shadowBlur normalization the wrapper exists for.

import QtQuick
import QtTest
import org.kde.latte.components 1.0 as LatteComponents

TestCase {
    id: root
    name: "ShadowedItemTest"
    when: windowShown

    Rectangle {
        id: sourceRect
        width: 24
        height: 24
        color: "red"
        visible: false
    }

    LatteComponents.ShadowedItem {
        id: shadowed
        source: sourceRect
        width: 24
        height: 24
    }

    function test_typeResolvesThroughModuleImport() {
        verify(shadowed !== null, "ShadowedItem must resolve as a type from org.kde.latte.components");
        verify(shadowed.shadowEnabled, "the wrapper is a preconfigured drop shadow");
        verify(shadowed.autoPaddingEnabled);
    }

    function test_shadowBlurNormalization() {
        //! shadowSizePx carries the old DropShadow.radius in pixels and maps
        //! linearly onto MultiEffect's 0..1 shadowBlur, saturating at blurMaxPx
        shadowed.blurMaxPx = 256;

        shadowed.shadowSizePx = 0;
        compare(shadowed.shadowBlur, 0.0);

        shadowed.shadowSizePx = 128;
        compare(shadowed.shadowBlur, 0.5);

        shadowed.shadowSizePx = 256;
        compare(shadowed.shadowBlur, 1.0);

        //! past the ceiling it clamps instead of overflowing
        shadowed.shadowSizePx = 1024;
        compare(shadowed.shadowBlur, 1.0);
    }

    function test_blurCeilingCoversIconSizeCap() {
        //! the largest real shadow size is 0.5 * the 512px icon-size cap;
        //! the default ceiling must sit at or above it so big-icon shadows
        //! scale instead of clamping early
        verify(shadowed.blurMaxPx >= 256);
    }
}
