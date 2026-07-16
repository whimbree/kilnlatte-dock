/*
    SPDX-FileCopyrightText: 2026 Bree Spektor
    SPDX-FileCopyrightText: 2026 Latte Dock contributors
    SPDX-License-Identifier: GPL-2.0-or-later
*/

#include "wheelstepper.h"

// Qt
#include <QDebug>

namespace Latte {

//! the QML-facing enum mirrors the core's; a drifted value would remap
//! every site's axis read silently, so the compiler holds them in sync
static_assert(static_cast<int>(WheelStepper::VerticalElseNegatedHorizontal)
                  == static_cast<int>(WheelAxisPick::VerticalElseNegatedHorizontal),
              "WheelStepper::AxisPick drifted from Latte::WheelAxisPick");
static_assert(static_cast<int>(WheelStepper::DominantAxis) == static_cast<int>(WheelAxisPick::DominantAxis),
              "WheelStepper::AxisPick drifted from Latte::WheelAxisPick");
static_assert(static_cast<int>(WheelStepper::SignedExtreme) == static_cast<int>(WheelAxisPick::SignedExtreme),
              "WheelStepper::AxisPick drifted from Latte::WheelAxisPick");
static_assert(static_cast<int>(WheelStepper::VerticalOnly) == static_cast<int>(WheelAxisPick::VerticalOnly),
              "WheelStepper::AxisPick drifted from Latte::WheelAxisPick");

WheelStepper::WheelStepper(QObject *parent)
    : QObject(parent)
{
}

WheelStepper::AxisPick WheelStepper::axisPick() const
{
    return m_axisPick;
}

void WheelStepper::setAxisPick(AxisPick axisPick)
{
    switch (axisPick) {
    case VerticalElseNegatedHorizontal:
    case DominantAxis:
    case SignedExtreme:
    case VerticalOnly:
        break;
    default:
        //! QML converts a plain int assignment into the enum without a
        //! range check; refuse the ones that name no strategy
        qCritical() << "WheelStepper: rejected out-of-range axisPick" << static_cast<int>(axisPick);
        return;
    }

    if (m_axisPick == axisPick) {
        return;
    }

    m_axisPick = axisPick;
    m_accumulator.reset();
    Q_EMIT axisPickChanged();
}

int WheelStepper::stepSize() const
{
    return m_stepSize;
}

void WheelStepper::setStepSize(int stepSize)
{
    if (m_stepSize == stepSize) {
        return;
    }

    m_stepSize = stepSize;
    m_accumulator.reset();
    Q_EMIT stepSizeChanged();
}

bool WheelStepper::resetOnReversal() const
{
    return m_resetOnReversal;
}

void WheelStepper::setResetOnReversal(bool resetOnReversal)
{
    if (m_resetOnReversal == resetOnReversal) {
        return;
    }

    m_resetOnReversal = resetOnReversal;
    m_accumulator.reset();
    Q_EMIT resetOnReversalChanged();
}

int WheelStepper::fireThreshold() const
{
    return m_fireThreshold;
}

void WheelStepper::setFireThreshold(int fireThreshold)
{
    if (m_fireThreshold == fireThreshold) {
        return;
    }

    m_fireThreshold = fireThreshold;
    m_accumulator.reset();
    Q_EMIT fireThresholdChanged();
}

int WheelStepper::add(QPointF angleDelta, bool inverted)
{
    if (!m_accumulator && !rebuildAccumulator()) {
        return 0;
    }

    return m_accumulator->add(angleDelta.toPoint(), inverted);
}

bool WheelStepper::verticalIsDominant(QPointF angleDelta) const
{
    return WheelAccumulator::verticalIsDominant(angleDelta.toPoint());
}

bool WheelStepper::rebuildAccumulator()
{
    const bool accumulating = (m_stepSize != 0);
    const bool thresholding = (m_fireThreshold >= 0);

    if (accumulating == thresholding) {
        qCritical() << "WheelStepper: exactly one of stepSize / fireThreshold must be configured"
                    << "(stepSize" << m_stepSize << "fireThreshold" << m_fireThreshold << ") - no steps will fire";
        return false;
    }

    if (accumulating && m_stepSize < 0) {
        qCritical() << "WheelStepper: rejected negative stepSize" << m_stepSize << "- no steps will fire";
        return false;
    }

    if (thresholding && m_resetOnReversal) {
        qCritical() << "WheelStepper: resetOnReversal is an accumulate-mode knob; threshold mode has no"
                    << "residue to reset (fireThreshold" << m_fireThreshold << ") - no steps will fire";
        return false;
    }

    const auto axisPick = static_cast<WheelAxisPick>(m_axisPick);
    if (accumulating) {
        m_accumulator.emplace(axisPick, AccumulateEveryStep{.stepSize = m_stepSize, .resetOnReversal = m_resetOnReversal});
    } else {
        m_accumulator.emplace(axisPick, FireOncePastThreshold{.threshold = m_fireThreshold});
    }

    return true;
}

}
