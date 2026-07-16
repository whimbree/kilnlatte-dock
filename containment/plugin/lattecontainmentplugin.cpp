/*
    SPDX-FileCopyrightText: 2020 Michail Vourlakos <mvourlakos@gmail.com>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

#include "lattecontainmentplugin.h"

// local
#include "autosizestepper.h"
#include "filldistributortools.h"
#include "colorizerdecider.h"
#include "backgroundstateresolver.h"
#include "iconcolorfulness.h"
#include "layoutmanager.h"
#include "types.h"

// Qt
#include <QtQml>

void LatteContainmentPlugin::registerTypes(const char *uri)
{
    Q_ASSERT(uri == QLatin1String("org.kde.latte.private.containment"));
    qmlRegisterUncreatableType<Latte::Containment::Types>(uri, 0, 1, "Types", "Latte Containment Types uncreatable");
    qmlRegisterType<Latte::Containment::LayoutManager>(uri, 0, 1, "LayoutManager");
    qmlRegisterType<Latte::Containment::IconColorfulness>(uri, 0, 1, "IconColorfulness");
    qmlRegisterType<Latte::Containment::AutoSizeStepper>(uri, 0, 1, "AutoSizeStepper");
    qmlRegisterSingletonType<Latte::FillDistributorTools>(uri, 0, 1, "FillDistributor", &Latte::filldistributortools_qobject_singletontype_provider);
    qmlRegisterType<Latte::Containment::ColorizerDecider>(uri, 0, 1, "ColorizerDecider");
    qmlRegisterType<Latte::Containment::BackgroundStateResolver>(uri, 0, 1, "BackgroundStateResolver");
}

