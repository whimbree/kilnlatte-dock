/*
    SPDX-FileCopyrightText: 2026 Bree Spektor
    SPDX-License-Identifier: GPL-2.0-or-later
*/

//! Pins the pure layer-shell mapping functions in app/wm/waylandlayershell.h.
//! These mappings are the compositor-facing contract of the wayland port:
//! anchors place the dock (setPosition is ignored for layer surfaces),
//! exclusive zones are the struts, and two of the cases below encode protocol
//! rules whose violation kills the surface or aborts the client outright.

#include "wm/waylandlayershell.h"

// Qt
#include <QRegion>
#include <QtTest>

using namespace Latte::WindowSystem;
using LSW = LayerShellQt::Window;

class LayerShellMappingTest : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void anchorsForBottomEdge();
    void anchorsForLeftEdge();
    void exclusiveEdgeIsAlwaysAnchored();
    void layerByVisibilityMode();
    void exclusiveZoneByLocation();
    void seededSizeForUnspannedAxes();
    void canvasPlacementByEdge();
    void canvasInputRegionPlainEditMode();
    void canvasInputRegionConfigureAppletsClickThrough();
    void canvasInputRegionKeepsChromeInteractive();
};

void LayerShellMappingTest::anchorsForBottomEdge()
{
    QCOMPARE(LayerShell::anchorsFor(Plasma::Types::BottomEdge, Latte::Types::Center),
             LSW::Anchors(LSW::AnchorBottom));
    QCOMPARE(LayerShell::anchorsFor(Plasma::Types::BottomEdge, Latte::Types::Left),
             LSW::Anchors(LSW::AnchorBottom | LSW::AnchorLeft));
    QCOMPARE(LayerShell::anchorsFor(Plasma::Types::BottomEdge, Latte::Types::Right),
             LSW::Anchors(LSW::AnchorBottom | LSW::AnchorRight));
    QCOMPARE(LayerShell::anchorsFor(Plasma::Types::BottomEdge, Latte::Types::Justify),
             LSW::Anchors(LSW::AnchorBottom | LSW::AnchorLeft | LSW::AnchorRight));
}

void LayerShellMappingTest::anchorsForLeftEdge()
{
    QCOMPARE(LayerShell::anchorsFor(Plasma::Types::LeftEdge, Latte::Types::Center),
             LSW::Anchors(LSW::AnchorLeft));
    QCOMPARE(LayerShell::anchorsFor(Plasma::Types::LeftEdge, Latte::Types::Top),
             LSW::Anchors(LSW::AnchorLeft | LSW::AnchorTop));
    QCOMPARE(LayerShell::anchorsFor(Plasma::Types::LeftEdge, Latte::Types::Bottom),
             LSW::Anchors(LSW::AnchorLeft | LSW::AnchorBottom));
    QCOMPARE(LayerShell::anchorsFor(Plasma::Types::LeftEdge, Latte::Types::Justify),
             LSW::Anchors(LSW::AnchorLeft | LSW::AnchorTop | LSW::AnchorBottom));
}

void LayerShellMappingTest::exclusiveEdgeIsAlwaysAnchored()
{
    //! updateAnchoring() sets edgeFor(location) as the exclusive edge right
    //! after anchorsFor(location, alignment). That is only legal if the edge
    //! is among the anchors for every combination: the compositor kills a
    //! surface whose exclusive edge is not one of its anchors.
    const QList<Plasma::Types::Location> locations{
        Plasma::Types::TopEdge, Plasma::Types::BottomEdge,
        Plasma::Types::LeftEdge, Plasma::Types::RightEdge};
    const QList<Latte::Types::Alignment> alignments{
        Latte::Types::Center, Latte::Types::Left, Latte::Types::Right,
        Latte::Types::Top, Latte::Types::Bottom, Latte::Types::Justify};

    for (const auto location : locations) {
        for (const auto alignment : alignments) {
            const LSW::Anchors anchors = LayerShell::anchorsFor(location, alignment);
            QVERIFY2(anchors.testFlag(LayerShell::edgeFor(location)),
                     qPrintable(QStringLiteral("exclusive edge not anchored for location=%1 alignment=%2")
                                    .arg(int(location)).arg(int(alignment))));
        }
    }
}

void LayerShellMappingTest::layerByVisibilityMode()
{
    QCOMPARE(LayerShell::layerFor(Latte::Types::WindowsCanCover), LSW::LayerBottom);
    QCOMPARE(LayerShell::layerFor(Latte::Types::WindowsAlwaysCover), LSW::LayerBottom);
    QCOMPARE(LayerShell::layerFor(Latte::Types::WindowsGoBelow), LSW::LayerBottom);
    QCOMPARE(LayerShell::layerFor(Latte::Types::AlwaysVisible), LSW::LayerTop);
    QCOMPARE(LayerShell::layerFor(Latte::Types::AutoHide), LSW::LayerTop);
    QCOMPARE(LayerShell::layerFor(Latte::Types::DodgeActive), LSW::LayerTop);
    QCOMPARE(LayerShell::layerFor(Latte::Types::NormalWindow), LSW::LayerTop);
}

void LayerShellMappingTest::exclusiveZoneByLocation()
{
    QCOMPARE(LayerShell::exclusiveZoneFor(QRect(0, 1040, 1920, 40), Plasma::Types::BottomEdge), 40);
    QCOMPARE(LayerShell::exclusiveZoneFor(QRect(0, 0, 1920, 40), Plasma::Types::TopEdge), 40);
    QCOMPARE(LayerShell::exclusiveZoneFor(QRect(0, 0, 48, 1080), Plasma::Types::LeftEdge), 48);
    QCOMPARE(LayerShell::exclusiveZoneFor(QRect(1872, 0, 48, 1080), Plasma::Types::RightEdge), 48);
    QCOMPARE(LayerShell::exclusiveZoneFor(QRect(), Plasma::Types::BottomEdge), 0);
}

void LayerShellMappingTest::seededSizeForUnspannedAxes()
{
    const QSize screen(1920, 1080);

    //! a Center bottom dock anchors a single edge; a 0x0 window must be
    //! seeded (length -> screen width, thickness -> 1px) or the first
    //! surface commit is protocol-rejected
    const auto bottomCenter = LayerShell::anchorsFor(Plasma::Types::BottomEdge, Latte::Types::Center);
    QCOMPARE(LayerShell::seededLayerSize(bottomCenter, Plasma::Types::BottomEdge, QSize(0, 0), screen),
             QSize(1920, 1));

    //! an already-sized window stays untouched, so re-running on a runtime
    //! edge change is safe
    QCOMPARE(LayerShell::seededLayerSize(bottomCenter, Plasma::Types::BottomEdge, QSize(800, 48), screen),
             QSize(800, 48));

    //! a Justify dock spans left+right, so width 0 is legal (the compositor
    //! stretches it) and must not be overwritten
    const auto bottomJustify = LayerShell::anchorsFor(Plasma::Types::BottomEdge, Latte::Types::Justify);
    QCOMPARE(LayerShell::seededLayerSize(bottomJustify, Plasma::Types::BottomEdge, QSize(0, 48), screen),
             QSize(0, 48));

    //! vertical dock: thickness is the width, length axis is vertical
    const auto leftCenter = LayerShell::anchorsFor(Plasma::Types::LeftEdge, Latte::Types::Center);
    QCOMPARE(LayerShell::seededLayerSize(leftCenter, Plasma::Types::LeftEdge, QSize(0, 0), screen),
             QSize(1, 1080));
}

void LayerShellMappingTest::canvasPlacementByEdge()
{
    const QRect screen(0, 0, 1920, 1080);

    //! horizontal docks: the canvas spans the full screen width on the dock
    //! edge, zero margins
    const auto bottom = LayerShell::canvasPlacement(Plasma::Types::BottomEdge, QRect(0, 1040, 1920, 40), screen);
    QCOMPARE(bottom.anchors, LSW::Anchors(LSW::AnchorBottom | LSW::AnchorLeft | LSW::AnchorRight));
    QCOMPARE(bottom.margins, QMargins(0, 0, 0, 0));

    const auto top = LayerShell::canvasPlacement(Plasma::Types::TopEdge, QRect(0, 0, 1920, 40), screen);
    QCOMPARE(top.anchors, LSW::Anchors(LSW::AnchorTop | LSW::AnchorLeft | LSW::AnchorRight));
    QCOMPARE(top.margins, QMargins(0, 0, 0, 0));

    //! vertical docks: the canvas starts at the available area's top (y=100
    //! here, below a top panel), carried by a top margin on a top anchor -
    //! margins only take effect on anchored edges
    const auto left = LayerShell::canvasPlacement(Plasma::Types::LeftEdge, QRect(0, 100, 48, 980), screen);
    QCOMPARE(left.anchors, LSW::Anchors(LSW::AnchorLeft | LSW::AnchorTop));
    QCOMPARE(left.margins, QMargins(0, 100, 0, 0));

    const auto right = LayerShell::canvasPlacement(Plasma::Types::RightEdge, QRect(1872, 200, 48, 880), screen);
    QCOMPARE(right.anchors, LSW::Anchors(LSW::AnchorRight | LSW::AnchorTop));
    QCOMPARE(right.margins, QMargins(0, 200, 0, 0));
}

void LayerShellMappingTest::canvasInputRegionPlainEditMode()
{
    //! plain edit mode: the whole canvas catches input (wheel -> background
    //! opacity, ruler dragging, context menu), including over the dock
    const QSize canvas(1920, 40);
    const QRegion region = LayerShell::canvasInputRegion(false, canvas, QRect());

    QCOMPARE(region, QRegion(QRect(0, 0, 1920, 40)));
    QVERIFY(region.contains(QPoint(960, 20)));
}

void LayerShellMappingTest::canvasInputRegionConfigureAppletsClickThrough()
{
    //! configure-applets mode without chrome: the canvas overlays the dock,
    //! so it must catch no on-surface pixel or every right-click/drag hits
    //! the grid instead of the widgets
    const QSize canvas(1920, 40);
    const QRegion region = LayerShell::canvasInputRegion(true, canvas, QRect());

    QVERIFY2(region.intersected(QRect(QPoint(0, 0), canvas)).isEmpty(),
             "the on-surface input area must be empty so events reach the dock beneath");

    //! and it must express that with an off-surface region, not an empty
    //! QRegion: the Qt wayland plugin maps an empty mask to the infinite
    //! (grab-all) input region, the exact opposite of click-through
    QVERIFY2(!region.isEmpty(),
             "click-through needs an off-surface region; an empty QRegion means grab-all on wayland");
}

void LayerShellMappingTest::canvasInputRegionKeepsChromeInteractive()
{
    //! configure-applets mode with chrome (the rearrange/exit toggle strip):
    //! the chrome keeps catching input, the dock area stays click-through
    const QSize canvas(1920, 40);
    const QRect chrome(0, 0, 1920, 8);
    const QRegion region = LayerShell::canvasInputRegion(true, canvas, chrome);

    QVERIFY(region.contains(QPoint(960, 4)));
    QVERIFY(!region.contains(QPoint(960, 30)));
}

QTEST_MAIN(LayerShellMappingTest)

#include "layershellmappingtest.moc"
