/*
    SPDX-FileCopyrightText: 2026 Bree Spektor
    SPDX-FileCopyrightText: 2026 Latte Dock contributors
    SPDX-License-Identifier: GPL-2.0-or-later
*/

// InputMaskFlush (app/view/inputmaskflush.h): the pure "what region to hand
// QWindow::setMask" decision behind Effects::applyInputMaskToWindow. It exists
// because Qt6's wayland backend clips each frame's submitted buffer damage to
// the window mask: narrowing the mask the instant a masked dock's band shrinks
// along its LENGTH axis strands the just-vacated edge pixels, whose transparent
// repaint is dropped, and the compositor keeps compositing stale semi-
// transparent panel content there (a lighter frosted band at the former extent
// - caught live on a real top dock 2026-07-18 when "maximize panel length in
// presence of maximized windows" grew the dock to full width and released on
// un-maximize).
//
// The invariant this pins: a LENGTH-axis SHRINK keeps the window mask at the
// union of the bands (never clips the vacated region) and only a settle collapse
// narrows it back to the band. Reverting the seam to a direct setMask(band) -
// the shape both reference forks still ship - reintroduces the stale band and
// fails shrinkKeepsUnionUntilSettle below.
//
// The scoping this pins: a THICKNESS-axis shrink (the autohide/dodge HIDE
// collapsing the band to its reveal strip, same length, thinner) is NOT held -
// the dock leaves, nothing is stranded where it stood, and holding the former
// band as the window mask would over-capture pointer input across the hidden
// dock's body. thicknessShrinkAppliesBandDirectly pins that.
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
// of two plain value types plus the length axis, no object, no sentinel to
// misread
static_assert(std::is_same_v<decltype(windowMaskFor(QRect(), QRect(), Qt::Horizontal)), QRect>,
              "windowMaskFor stays a pure QRect->QRect->axis->QRect decision");
static_assert(std::is_same_v<decltype(needsSettleCollapse(QRect(), QRect())), bool>,
              "needsSettleCollapse stays a pure predicate");

class InputMaskFlushTest : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void clearBandClearsMask();
    void firstBandAppliedAsIs();
    void growAppliesBandDirectly();
    void shrinkKeepsUnionNotBand();
    void settlePredicateTracksWidth();
    void maximizeCycleReproduction();
    void shrinkKeepsUnionUntilSettle();
    void animatedShrinkNeverClipsVacatedEdges();
    void thicknessShrinkAppliesBandDirectly();
    void verticalDockHoldsOnHeightShrink();
};

//! A degenerate/clear band (width 0, or the Qt.rect(0,0,-1,-1) explicit clear
//! sentinel the QML mask core emits) clears the window mask regardless of what
//! was applied before.
void InputMaskFlushTest::clearBandClearsMask()
{
    const QRect applied(0, 0, 1440, 32);

    QCOMPARE(windowMaskFor(applied, QRect(), Qt::Horizontal), QRect());
    QCOMPARE(windowMaskFor(applied, QRect(0, 0, 0, 0), Qt::Horizontal), QRect());
    QCOMPARE(windowMaskFor(applied, QRect(0, 0, -1, -1), Qt::Horizontal), QRect());
    // nothing to collapse to once cleared
    QVERIFY(!needsSettleCollapse(QRect(), QRect()));
}

//! With no prior applied mask (startup) the band is handed through unchanged;
//! there is no vacated region to protect yet.
void InputMaskFlushTest::firstBandAppliedAsIs()
{
    const QRect band(44, 8, 1353, 24);

    QCOMPARE(windowMaskFor(QRect(), band, Qt::Horizontal), band);
    QCOMPARE(windowMaskFor(QRect(0, 0, 0, 0), band, Qt::Horizontal), band);
    QVERIFY(!needsSettleCollapse(band, band));
}

//! Growing (un-maximized band -> full width): a grow is not a length shrink, so
//! the band is applied directly and no collapse is owed. Growing never strands.
void InputMaskFlushTest::growAppliesBandDirectly()
{
    const QRect band(44, 8, 1353, 24);
    const QRect full(0, 0, 1440, 32);

    const QRect grown = windowMaskFor(band, full, Qt::Horizontal);
    QCOMPARE(grown, full);
    QVERIFY(!needsSettleCollapse(grown, full));
}

//! Shrinking along the length axis (full width -> band): the union stays at the
//! wider applied region, NOT the band, so the vacated edges [0,44) and
//! [1397,1440) remain inside the window mask and their clearing damage is not
//! clipped. A collapse is owed.
void InputMaskFlushTest::shrinkKeepsUnionNotBand()
{
    const QRect full(0, 0, 1440, 32);
    const QRect band(44, 8, 1353, 24);

    const QRect shrunk = windowMaskFor(full, band, Qt::Horizontal);
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
    applied = windowMaskFor(applied, full, Qt::Horizontal);
    QCOMPARE(applied, full);
    QVERIFY(!needsSettleCollapse(applied, full));

    // un-maximize: band shrinks; the applied mask must NOT snap to the band
    applied = windowMaskFor(applied, band, Qt::Horizontal);
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

    const QRect appliedDuringShrink = windowMaskFor(full, band, Qt::Horizontal);
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
        applied = windowMaskFor(applied, step, Qt::Horizontal);
        // never clips below the widest band seen so far in the burst
        QVERIFY(applied.contains(steps[0]));
    }

    // and the whole burst stayed pinned at the burst maximum until settle
    QCOMPARE(applied, steps[0]);
    QVERIFY(needsSettleCollapse(applied, steps[3]));
}

//! An autohide/dodge HIDE collapses the band to its reveal strip: same LENGTH
//! (width, for a horizontal dock), thinner. That is a THICKNESS-axis shrink, not
//! a length one - the dock leaves, nothing stale is stranded where it stood - so
//! the band (the strip) is applied DIRECTLY, never the union. Holding the former
//! band here would keep the whole vacated dock body as the window mask while the
//! dock is hidden, over-capturing pointer input (clicks swallowed, the reveal
//! strip widened). No collapse is owed.
void InputMaskFlushTest::thicknessShrinkAppliesBandDirectly()
{
    const QRect shown(44, 8, 1353, 24);   // shown band, 24px thick
    const QRect strip(44, 30, 1353, 2);   // reveal strip, same width, 2px thick

    const QRect hidden = windowMaskFor(shown, strip, Qt::Horizontal);
    QCOMPARE(hidden, strip);               // strip applied directly, not united
    QVERIFY(!needsSettleCollapse(hidden, strip));

    // and the reverse (strip -> shown, a thickness GROW on reveal) also applies
    // the band directly
    QCOMPARE(windowMaskFor(strip, shown, Qt::Horizontal), shown);
}

//! For a Left/Right dock the LENGTH axis is vertical: a height shrink is the
//! frosted-band case and is held at the union, while a width (thickness) shrink
//! is applied directly. The mirror of the horizontal cases above.
void InputMaskFlushTest::verticalDockHoldsOnHeightShrink()
{
    const QRect fullV(0, 0, 32, 1440);    // full-height left dock band
    const QRect bandV(8, 44, 24, 1353);   // shorter band

    // length (height) shrink: union held
    const QRect shrunk = windowMaskFor(fullV, bandV, Qt::Vertical);
    QCOMPARE(shrunk, fullV);
    QVERIFY(needsSettleCollapse(shrunk, bandV));

    // thickness (width) shrink to a reveal strip: applied directly
    const QRect stripV(0, 44, 2, 1353);   // same height as bandV, 2px thick
    QCOMPARE(windowMaskFor(bandV, stripV, Qt::Vertical), stripV);
    QVERIFY(!needsSettleCollapse(windowMaskFor(bandV, stripV, Qt::Vertical), stripV));
}

QTEST_APPLESS_MAIN(InputMaskFlushTest)
#include "inputmaskflushtest.moc"
