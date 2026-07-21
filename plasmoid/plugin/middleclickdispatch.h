/*
    SPDX-FileCopyrightText: 2026 Latte Dock contributors
    SPDX-FileCopyrightText: 2026 Bree Spektor
    SPDX-License-Identifier: GPL-2.0-or-later
*/

#pragma once

#include "types.h"

#include <QString>
#include <QtGlobal>

namespace Latte::Tasks {

enum class MiddleClickRowKind {
    Launcher = 0,
    Task
};

enum class MiddleClickOperation {
    None = 0,
    RequestActivate,
    RequestClose,
    RequestNewInstance,
    RequestToggleMinimized,
    CycleOrActivate,
    RequestToggleGrouping
};

struct MiddleClickDispatchRecord {
    QString rowIdentity;
    MiddleClickRowKind rowKind{MiddleClickRowKind::Launcher};
    Types::TaskAction configuredAction{Types::NoneAction};
    MiddleClickOperation dispatchedOperation{MiddleClickOperation::None};
    qint64 sequence{0};
};

}
