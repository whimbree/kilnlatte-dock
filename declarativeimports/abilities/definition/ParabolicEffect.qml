/*
    SPDX-FileCopyrightText: 2020 Michail Vourlakos <mvourlakos@gmail.com>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick 2.0

import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core 2.0 as PlasmaCore

import org.kde.latte.core 0.2 as LatteCore

import "./paraboliceffect" as ParabolicEffectTypes

Item {
    property bool isEnabled: false
    property bool restoreZoomIsBlocked: false

    property int spread: 3

    property ParabolicEffectTypes.Factor factor: ParabolicEffectTypes.Factor{
        zoom: 1.6
        maxZoom: 1.6
        marginThicknessZoomInPercentage: 1.0
    }

    readonly property ParabolicEffectTypes.PrivateProperties _privates: ParabolicEffectTypes.PrivateProperties {
        directRenderingEnabled: false
    }

    property Item currentParabolicItem: null

    signal sglClearZoom();
    signal sglUpdateLowerItemScale(int delegateIndex, variant newScales);
    signal sglUpdateHigherItemScale(int delegateIndex, variant newScales);

    readonly property int _spreadSteps: (spread - 1) / 2

    //! the curve math lives in LatteCore.ParabolicMath (EX-03,
    //! declarativeimports/core/units/parabolicmath.h, equivalence-tested
    //! against the QML body this replaced); this keeps ownership of the
    //! layout-direction read and the signal emissions
    function applyParabolicEffect(itemIndex, itemMousePosition, itemLength) {
        var reversed = Qt.application.layoutDirection === Qt.RightToLeft && (Plasmoid.formFactor === PlasmaCore.Types.Horizontal);
        var stacks = LatteCore.ParabolicMath.computeScales(itemMousePosition / itemLength, _spreadSteps, factor.zoom, reversed);

        sglUpdateHigherItemScale(itemIndex+1, stacks.right);
        sglUpdateLowerItemScale(itemIndex-1, stacks.left);

        return {leftScale:stacks.left[0], rightScale:stacks.right[0]};
    }
}
