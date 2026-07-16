/*
    SPDX-FileCopyrightText: 2026 Bree Spektor
    SPDX-FileCopyrightText: 2026 Latte Dock contributors
    SPDX-License-Identifier: GPL-2.0-or-later

    Latte-authored, NOT part of the plasma-desktop vendored set in this
    directory (see plasmoid/plugin/units/README.md).
*/

#ifndef SCROLLOVERFLOWMATH_H
#define SCROLLOVERFLOWMATH_H

// Qt
#include <QObject>
#include <QVariant>
#include <QVariantMap>

namespace Latte {
namespace Tasks {

//! Thin QML shell over the ScrollMath core (EX-21): the stateless
//! LatteTasks.ScrollOverflowMath singleton ScrollableList.qml calls. The
//! core decides (units/scrollmath.h); this wrapper converts QML arguments,
//! refuses malformed calls loudly, and converts the core's nullopt to
//! undefined - the "no scroll" sentinel exists only at this boundary.
//!
//! Signed axis convention (the core's): positive deltas scroll toward the
//! row end, negative toward the row start; the shell resolves which of
//! contentX/contentY that means.
class ScrollOverflowMath : public QObject
{
    Q_OBJECT

public:
    explicit ScrollOverflowMath(QObject *parent = nullptr);

    Q_INVOKABLE bool contentsExceed(bool scrollingEnabled, double contentLength,
                                    int viewportLength) const;
    Q_INVOKABLE int contentsExtraSpace(bool scrollingEnabled, double contentLength,
                                       int viewportLength) const;
    Q_INVOKABLE double wheelScrollStep(double totalsLength) const;
    Q_INVOKABLE double steppedPos(bool scrollingEnabled, double contentLength,
                                  int viewportLength, double currentPos,
                                  double signedStep) const;
    //! double (the signed step) or undefined (no scroll needed)
    Q_INVOKABLE QVariant focusScrollDelta(bool scrollingEnabled, double contentLength,
                                          int viewportLength, double itemStart,
                                          double itemLength, double margin) const;
    //! facts keys (all required - too many for readable positional args, so
    //! they travel named, the composeSubText precedent): scrollingEnabled,
    //! contentLength, viewportLength, currentPos, itemStart, itemLength,
    //! triggerZone, autoScrollTasksEnabled, duringDragging, tasksCount,
    //! hoveredIsLastVisibleItem, parabolicZoomFactor,
    //! scrollAnimationRunning, totalsLength.
    //! Returns double (the signed step) or undefined (no scroll).
    Q_INVOKABLE QVariant autoScrollDelta(const QVariantMap &facts) const;
    //! double (the in-bounds position to write) or undefined (already in
    //! bounds - no write, so the Behavior animation is not touched)
    Q_INVOKABLE QVariant boundsCorrection(bool scrollingEnabled, double contentLength,
                                          int viewportLength, double currentPos) const;
};

}
}

#endif
