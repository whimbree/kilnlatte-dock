/*
    SPDX-FileCopyrightText: 2026 Bree Spektor
    SPDX-FileCopyrightText: 2026 Latte Dock contributors
    SPDX-License-Identifier: GPL-2.0-or-later
*/

// InputMaskFlush (app/view/inputmaskflush.h): the pure "what region to hand
// QWindow::setMask" decision behind Effects::applyInputMaskToWindow. It exists
// because Qt6's wayland backend clips each frame's submitted buffer damage to
// the window mask: narrowing the mask the instant a masked dock's band shrinks
// strands the just-vacated edge pixels, whose transparent repaint is dropped,
// and the compositor keeps compositing stale semi-transparent panel content
// there (a lighter frosted band at the former extent - caught live on a real
// top dock 2026-07-18 when "maximize panel length in presence of maximized
// windows" grew the dock to full width and released on un-maximize).
//
// The invariant this pins: a SHRINK keeps the window mask at the union of the
// bands (never clips the vacated region) and only a settle collapse narrows it
// back to the band. Reverting the seam to a direct setMask(band) - the shape
// both reference forks still ship - reintroduces the stale band and fails
// shrinkKeepsUnionUntilSettle below.
//
// Every expected rect is hand-derived from the QRect union geometry, not
// produced by running the header under test.

#include <QtTest>

// Qt
#include <QRect>

// C++
#include <type_traits>

#include "../../app/view/inputmaskflush.h"

using namespace Latte::ViewPart::InputMaskFlush;

// invalid states designed out (step-2.5 law): the decision is a pure function
// of two plain value types, no object, no sentinel to misread
static_assert(std::is_same_v<decltype(windowMaskFor(QRect(), QRect())), QRect>,
              "windowMaskFor stays a pure QRect->QRect->QRect decision");
static_assert(std::is_same_v<decltype(needsSettleCollapse(QRect(), QRect())), bool>,
              "needsSettleCollapse stays a pure predicate");

class InputMaskFlushTest : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void clearBandClearsMask();
    void firstBandAppliedAsIs();
    void growCollapsesToBandImmediately();
    void shrinkKeepsUnionNotBand();
    void settlePredicateTracksWidth();
    void maximizeCycleReproduction();
    void shrinkKeepsUnionUntilSettle();
    void animatedShrinkNeverClipsVacatedEdges();
};

//! A degenerate/clear band (width 0, or the Qt.rect(0,0,-1,-1) explicit clear
//! sentinel the QML mask core emits) clears the window mask regardless of what
//! was applied before.
void InputMaskFlushTest::clearBandClearsMask()
{
    const QRect applied(0, 0, 1440, 32);

    QCOMPARE(windowMaskFor(applied, QRect()), QRect());
    QCOMPARE(windowMaskFor(applied, QRect(0, 0, 0, 0)), QRect());
    QCOMPARE(windowMaskFor(applied, QRect(0, 0, -1, -1)), QRect());
    // nothing to collapse to once cleared
    QVERIFY(!needsSettleCollapse(QRect(), QRect()));
}

//! With no prior applied mask (startup) the band is handed through unchanged;
//! there is no vacated region to protect yet.
void InputMaskFlushTest::firstBandAppliedAsIs()
{
    const QRect band(44, 8, 1353, 24);

    QCOMPARE(windowMaskFor(QRect(), band), band);
    QCOMPARE(windowMaskFor(QRect(0, 0, 0, 0), band), band);
    QVERIFY(!needsSettleCollapse(band, band));
}

//! Growing (un-maximized band -> full width): the wider band already contains
//! the old applied region, so the union equals the band and no collapse is
//! owed. Growing never strands, so it applies immediately.
void InputMaskFlushTest::growCollapsesToBandImmediately()
{
    const QRect band(44, 8, 1353, 24);
    const QRect full(0, 0, 1440, 32);

    const QRect grown = windowMaskFor(band, full);
    QCOMPARE(grown, full);
    QVERIFY(!needsSettleCollapse(grown, full));
}

//! Shrinking (full width -> band): the union stays at the wider applied region,
//! NOT the band, so the vacated edges [0,44) and [1397,1440) remain inside the
//! window mask and their clearing damage is not clipped. A collapse is owed.
void InputMaskFlushTest::shrinkKeepsUnionNotBand()
{
    const QRect full(0, 0, 1440, 32);
    const QRect band(44, 8, 1353, 24);

    const QRect shrunk = windowMaskFor(full, band);
    QCOMPARE(shrunk, full);                 // stays wide, does not narrow to band
    QVERIFY(shrunk.contains(band));
    QVERIFY(needsSettleCollapse(shrunk, band));

    // the left/right vacated slivers are still covered by the applied mask
    QVERIFY(shrunk.contains(QRect(0, 8, 44, 24)));      // left of the band
    QVERIFY(shrunk.contains(QRect(1397, 8, 43, 24)));   // right of the band
}

//! needsSettleCollapse is exactly "applied is a non-empty band wider than / not
//! equal to the logical band", the condition Effects arms its settle timer on.
void InputMaskFlushTest::settlePredicateTracksWidth()
{
    const QRect band(44, 8, 1353, 24);
    const QRect full(0, 0, 1440, 32);

    QVERIFY(needsSettleCollapse(full, band));    // wider -> collapse owed
    QVERIFY(!needsSettleCollapse(band, band));   // exact -> nothing owed
    QVERIFY(!needsSettleCollapse(full, QRect()));            // empty band -> nothing owed
    QVERIFY(!needsSettleCollapse(full, QRect(0, 0, 0, 0)));  // zero-size band -> nothing owed
    QVERIFY(!needsSettleCollapse(QRect(), QRect()));
}

//! The end-to-end state machine Effects drives across a maximizeWhenMaximized
//! cycle: band -> full (grow, applied==full) -> band (shrink, applied stays
//! full) -> settle collapse (applied==band). This is the exact sequence that
//! produced the live artifact before the fix.
void InputMaskFlushTest::maximizeCycleReproduction()
{
    const QRect band(44, 8, 1353, 24);
    const QRect full(0, 0, 1440, 32);

    QRect applied = band;                        // steady state before maximize

    // maximize: band grows to full
    applied = windowMaskFor(applied, full);
    QCOMPARE(applied, full);
    QVERIFY(!needsSettleCollapse(applied, full));

    // un-maximize: band shrinks; the applied mask must NOT snap to the band
    applied = windowMaskFor(applied, band);
    QCOMPARE(applied, full);
    QVERIFY(needsSettleCollapse(applied, band));

    // settle collapse (the timer's job): now narrow to the exact band
    applied = band;
    QVERIFY(!needsSettleCollapse(applied, band));
}

//! Re-stating the regression as a single assertion a future "simplification"
//! trips: while the band is the shrunk band, the applied window mask must still
//! cover the full former extent (so damage clears it). A direct setMask(band)
//! would make applied == band here and fail.
void InputMaskFlushTest::shrinkKeepsUnionUntilSettle()
{
    const QRect full(0, 0, 1440, 32);
    const QRect band(44, 8, 1353, 24);

    const QRect appliedDuringShrink = windowMaskFor(full, band);
    QVERIFY2(appliedDuringShrink == full,
             "a shrinking band must keep the window mask at the former (wider) "
             "extent so Qt6 wayland does not clip the vacated region's clearing "
             "damage; narrowing straight to the band reintroduces the stale band");
}

//! The shrink is animated (Behavior on length in the containment QML), so the
//! band arrives as many decreasing steps. Each step's union must still cover
//! every edge vacated since the burst began, i.e. the applied mask stays at the
//! burst maximum the whole way down. Verified by folding windowMaskFor across a
//! descending sequence and checking coverage of the first (widest) band.
void InputMaskFlushTest::animatedShrinkNeverClipsVacatedEdges()
{
    const QRect steps[] = {
        QRect(0, 0, 1440, 32),      // full width (maximized)
        QRect(20, 4, 1400, 28),
        QRect(30, 6, 1380, 26),
        QRect(44, 8, 1353, 24),     // settled band
    };

    QRect applied;
    for (const QRect &step : steps) {
        applied = windowMaskFor(applied, step);
        // never clips below the widest band seen so far in the burst
        QVERIFY(applied.contains(steps[0]));
    }

    // and the whole burst stayed pinned at the burst maximum until settle
    QCOMPARE(applied, steps[0]);
    QVERIFY(needsSettleCollapse(applied, steps[3]));
}

QTEST_APPLESS_MAIN(InputMaskFlushTest)
#include "inputmaskflushtest.moc"
