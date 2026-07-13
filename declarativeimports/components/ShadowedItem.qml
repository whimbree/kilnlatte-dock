/*
    SPDX-FileCopyrightText: 2026 Latte Dock contributors
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Effects
import "code/EffectMath.js" as EffectMath

// A MultiEffect preconfigured as a drop shadow. The root IS a MultiEffect, so
// callers set shadowColor/source/shadowHorizontalOffset/shadowVerticalOffset
// directly; this only adds shadowSizePx (the old px radius) and the blur ceiling.
MultiEffect {
    id: root
    property real shadowSizePx: 0      // == old DropShadow.radius in px
    // Pixel radius at which shadowBlur saturates to 1.0 (shadowSizePx == blurMaxPx
    // -> full blur). Sits above the largest itemShadow.size (0.5 * the 512px
    // icon-size cap = 256), so big-icon shadows scale instead of clamping early.
    property int  blurMaxPx: 256

    // STATIC padding, never autoPaddingEnabled. With autoPadding the effect
    // recomputes its padding continuously and re-dirties itself, so every
    // window carrying an applet shadow re-rendered EMPTY frames forever
    // (measured: 18.2% idle CPU on the main thread, ~19,500 failing statx/s
    // from per-frame theme lookups, both flat even with the docks hidden;
    // 0.1% with static padding, bisected across three probe builds). The
    // rect below grows the output by the blur extent plus the offsets on
    // every side, which is everything a drop shadow can paint, so the
    // rendered result is identical to what autoPadding produced.
    readonly property int shadowPaddingPx: Math.ceil(shadowSizePx
                                                     + Math.max(Math.abs(shadowHorizontalOffset), Math.abs(shadowVerticalOffset))
                                                     + 2)
    autoPaddingEnabled: false
    paddingRect: Qt.rect(shadowPaddingPx, shadowPaddingPx, 2*shadowPaddingPx, 2*shadowPaddingPx)

    shadowEnabled: true
    shadowOpacity: 1.0
    shadowHorizontalOffset: 0
    // Default matches the common old DropShadow.verticalOffset: 2; sites whose
    // old shadow used a different offset override this.
    shadowVerticalOffset: 2
    blurMax: blurMaxPx
    shadowBlur: EffectMath.shadowBlurFor(shadowSizePx, blurMaxPx)
}
