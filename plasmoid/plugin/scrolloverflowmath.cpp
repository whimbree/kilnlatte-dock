/*
    SPDX-FileCopyrightText: 2026 Bree Spektor
    SPDX-FileCopyrightText: 2026 Latte Dock contributors
    SPDX-License-Identifier: GPL-2.0-or-later
*/

#include "scrolloverflowmath.h"

// local
#include "units/scrollmath.h"

// Qt
#include <QDebug>

// C++
#include <cmath>
#include <optional>

namespace {

//! boundary refusal for the numeric arguments: QML can hand undefined
//! (arriving as NaN) or a garbage negative where a length belongs; the
//! core Q_ASSERTs these preconditions but asserts are test-time tripwires,
//! so the runtime boundary refuses loudly instead of computing from junk
bool refuseBadLength(const char *function, const char *name, double value)
{
    if (std::isfinite(value) && value >= 0.0) {
        return false;
    }
    qCritical() << "ScrollOverflowMath:" << function << "called with invalid" << name << value;
    return true;
}

bool refuseNonFinite(const char *function, const char *name, double value)
{
    if (std::isfinite(value)) {
        return false;
    }
    qCritical() << "ScrollOverflowMath:" << function << "called with non-finite" << name << value;
    return true;
}

std::optional<Latte::ScrollMath::ScrollEnv> envFromArgs(const char *function, bool scrollingEnabled,
                                                        double contentLength, int viewportLength,
                                                        double currentPos)
{
    if (refuseBadLength(function, "contentLength", contentLength)
            || refuseBadLength(function, "viewportLength", viewportLength)
            || refuseNonFinite(function, "currentPos", currentPos)) {
        return std::nullopt;
    }
    return Latte::ScrollMath::ScrollEnv{scrollingEnabled, contentLength, viewportLength, currentPos};
}

QVariant toQml(std::optional<double> delta)
{
    // nullopt -> invalid QVariant -> undefined in QML: the "no scroll"
    // sentinel exists only at this boundary
    return delta ? QVariant(*delta) : QVariant();
}

}

namespace Latte {
namespace Tasks {

ScrollOverflowMath::ScrollOverflowMath(QObject *parent)
    : QObject(parent)
{
}

bool ScrollOverflowMath::contentsExceed(bool scrollingEnabled, double contentLength,
                                        int viewportLength) const
{
    const auto env = envFromArgs("contentsExceed", scrollingEnabled, contentLength, viewportLength, 0.0);
    return env ? ScrollMath::contentsExceed(*env) : false;
}

int ScrollOverflowMath::contentsExtraSpace(bool scrollingEnabled, double contentLength,
                                           int viewportLength) const
{
    const auto env = envFromArgs("contentsExtraSpace", scrollingEnabled, contentLength, viewportLength, 0.0);
    return env ? ScrollMath::contentsExtraSpace(*env) : 0;
}

double ScrollOverflowMath::wheelScrollStep(double totalsLength) const
{
    if (refuseBadLength("wheelScrollStep", "totalsLength", totalsLength)) {
        return 0.0;
    }
    return ScrollMath::wheelScrollStep(totalsLength);
}

double ScrollOverflowMath::steppedPos(bool scrollingEnabled, double contentLength,
                                      int viewportLength, double currentPos,
                                      double signedStep) const
{
    const auto env = envFromArgs("steppedPos", scrollingEnabled, contentLength, viewportLength, currentPos);
    if (!env || refuseNonFinite("steppedPos", "signedStep", signedStep)) {
        // refusing a step means not moving; currentPos may itself be the
        // junk argument, in which case 0 (the row start) is the one always
        // valid position
        return std::isfinite(currentPos) ? currentPos : 0.0;
    }
    return ScrollMath::steppedPos(*env, signedStep);
}

QVariant ScrollOverflowMath::focusScrollDelta(bool scrollingEnabled, double contentLength,
                                              int viewportLength, double itemStart,
                                              double itemLength, double margin) const
{
    const auto env = envFromArgs("focusScrollDelta", scrollingEnabled, contentLength, viewportLength, 0.0);
    if (!env || refuseNonFinite("focusScrollDelta", "itemStart", itemStart)
            || refuseBadLength("focusScrollDelta", "itemLength", itemLength)
            || refuseBadLength("focusScrollDelta", "margin", margin)) {
        return QVariant();
    }
    return toQml(ScrollMath::focusScrollDelta(*env, {itemStart, itemLength}, margin));
}

QVariant ScrollOverflowMath::autoScrollDelta(const QVariantMap &facts) const
{
    // boundary refusal: a shell drifting a key name must fail loudly here,
    // not decide from silently-defaulted facts (the composeSubText shape)
    static const QStringList requiredKeys = {
        QStringLiteral("scrollingEnabled"),
        QStringLiteral("contentLength"),
        QStringLiteral("viewportLength"),
        QStringLiteral("currentPos"),
        QStringLiteral("itemStart"),
        QStringLiteral("itemLength"),
        QStringLiteral("triggerZone"),
        QStringLiteral("autoScrollTasksEnabled"),
        QStringLiteral("duringDragging"),
        QStringLiteral("tasksCount"),
        QStringLiteral("hoveredIsLastVisibleItem"),
        QStringLiteral("parabolicZoomFactor"),
        QStringLiteral("scrollAnimationRunning"),
        QStringLiteral("totalsLength"),
    };

    for (const QString &key : requiredKeys) {
        if (!facts.contains(key)) {
            qCritical() << "ScrollOverflowMath: autoScrollDelta called without fact" << key
                        << "- got keys" << facts.keys();
            return QVariant();
        }
    }

    const auto env = envFromArgs("autoScrollDelta",
                                 facts.value(QStringLiteral("scrollingEnabled")).toBool(),
                                 facts.value(QStringLiteral("contentLength")).toDouble(),
                                 facts.value(QStringLiteral("viewportLength")).toInt(),
                                 facts.value(QStringLiteral("currentPos")).toDouble());

    const double itemStart = facts.value(QStringLiteral("itemStart")).toDouble();
    const double itemLength = facts.value(QStringLiteral("itemLength")).toDouble();
    const double triggerZone = facts.value(QStringLiteral("triggerZone")).toDouble();
    const double parabolicZoomFactor = facts.value(QStringLiteral("parabolicZoomFactor")).toDouble();
    const double totalsLength = facts.value(QStringLiteral("totalsLength")).toDouble();
    const int tasksCount = facts.value(QStringLiteral("tasksCount")).toInt();

    if (!env || refuseNonFinite("autoScrollDelta", "itemStart", itemStart)
            || refuseBadLength("autoScrollDelta", "itemLength", itemLength)
            || refuseBadLength("autoScrollDelta", "triggerZone", triggerZone)
            || refuseNonFinite("autoScrollDelta", "parabolicZoomFactor", parabolicZoomFactor)
            || refuseBadLength("autoScrollDelta", "totalsLength", totalsLength)) {
        return QVariant();
    }

    if (tasksCount < 0) {
        qCritical() << "ScrollOverflowMath: autoScrollDelta called with negative tasksCount" << tasksCount;
        return QVariant();
    }

    const ScrollMath::AutoScrollGuards guards{
        facts.value(QStringLiteral("autoScrollTasksEnabled")).toBool(),
        facts.value(QStringLiteral("duringDragging")).toBool(),
        tasksCount,
        facts.value(QStringLiteral("hoveredIsLastVisibleItem")).toBool(),
        parabolicZoomFactor,
    };

    return toQml(ScrollMath::autoScrollDelta(*env, {itemStart, itemLength}, triggerZone, guards,
                                             facts.value(QStringLiteral("scrollAnimationRunning")).toBool(),
                                             totalsLength));
}

QVariant ScrollOverflowMath::boundsCorrection(bool scrollingEnabled, double contentLength,
                                              int viewportLength, double currentPos) const
{
    const auto env = envFromArgs("boundsCorrection", scrollingEnabled, contentLength, viewportLength, currentPos);
    if (!env) {
        return QVariant();
    }
    return toQml(ScrollMath::boundsCorrection(*env));
}

}
}
