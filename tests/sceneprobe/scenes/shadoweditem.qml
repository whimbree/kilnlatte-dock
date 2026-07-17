// SPDX-FileCopyrightText: 2026 Latte Dock contributors
// SPDX-FileCopyrightText: 2026 Bree Spektor
// SPDX-License-Identifier: GPL-2.0-or-later
//
// Renders our real org.kde.latte.components.ShadowedItem (a preconfigured
// MultiEffect drop shadow), resolved from the freshly staged source modules the
// gate puts on the import path. Ours carries the STATIC paddingRect contract
// (e3376405): with autoPaddingEnabled false, the shadow can only paint outside
// the item bounds if paddingRect is computed right - so the probeExpect entries
// assert red shadow presence OUTSIDE the source rect (above and below it, where
// a broken padding would clip it away) and clean white INSIDE the source. A
// wrong paddingRect (the smaller-ghost-copy failure caught live) also breaks
// the inside expectation, because the source re-renders scaled inside itself.
// The shadow is red on a gray background so its presence is measurable; a
// black-on-black shadow (the upstream scene's colors) asserts nothing.
import QtQuick
import org.kde.latte.components 1.0 as LatteComponents

Item {
    width: 256; height: 256
    // Expected values measured from the actual lavapipe render (2026-07-16,
    // pinned Mesa 26.1.2 / Qt 6.11). The source rect spans (73,98)-(183,157);
    // every "outside" point sits beyond the effect item's bounds, so a zeroed
    // or mis-scaled paddingRect clips the shadow there and leaves background
    // #303030, which the tolerances are sized to reject.
    property var probeExpect: [
        // below the bottom edge (shadow strongest: +2 vertical offset)
        { "x": 128, "y": 160, "rgba": "#7b1e1e", "tol": 0.15 },
        // right of the right edge
        { "x": 184, "y": 128, "rgba": "#642424", "tol": 0.15 },
        // above the top edge (weakest reach; tighter tol so a clipped shadow
        // reading background #303030 still fails)
        { "x": 128, "y": 97, "rgba": "#542828", "tol": 0.10 },
        // the source itself stays white (a mis-padded effect draws a shrunken
        // ghost copy here instead)
        { "x": 128, "y": 128, "rgba": "#ffffff", "tol": 0.05 },
        // background far from the shadow stays untouched
        { "x": 10, "y": 10, "rgba": "#303030", "tol": 0.05 }
    ]

    Rectangle { anchors.fill: parent; color: "#303030" }
    Rectangle { id: src; anchors.centerIn: parent; width: 110; height: 60; radius: 8; color: "white" }
    LatteComponents.ShadowedItem {
        anchors.fill: src
        source: src
        shadowColor: "red"
        shadowSizePx: 16
    }
}
