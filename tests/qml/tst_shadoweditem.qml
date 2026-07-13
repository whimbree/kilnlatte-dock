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
    }

    function test_staticPaddingNeverAuto() {
        //! autoPaddingEnabled makes MultiEffect recompute padding and
        //! re-dirty itself continuously - every shadowed window re-rendered
        //! empty frames forever (18.2% idle CPU, ~19.5k failing statx/s
        //! from per-frame theme lookups, measured 2026-07-13). The wrapper
        //! must carry a STATIC paddingRect sized to the blur instead.
        verify(!shadowed.autoPaddingEnabled,
               "autoPadding re-dirties the effect every frame; padding must be static");

        //! and the static rect must actually cover what the shadow paints:
        //! blur extent plus offsets on every side
        shadowed.shadowSizePx = 20;
        verify(shadowed.paddingRect.x >= 20 + Math.abs(shadowed.shadowVerticalOffset),
               "padding must cover blur radius plus offset");
        compare(shadowed.paddingRect.width, 2 * shadowed.paddingRect.x);
        compare(shadowed.paddingRect.height, 2 * shadowed.paddingRect.y);
        shadowed.shadowSizePx = 0;
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
