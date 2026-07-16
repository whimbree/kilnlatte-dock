/*
    SPDX-FileCopyrightText: 2026 Latte Dock contributors
    SPDX-FileCopyrightText: 2026 Bree Spektor
    SPDX-License-Identifier: GPL-2.0-or-later
*/

// The pure layer of the viewsData() D-Bus read
// (docs/dbus-observability-interface.md): ViewRecord -> JSON serialization
// and the enum-name mappings. The live collectors in app/dbusreports.cpp
// are three-line field reads off View and stay exercised by the running
// dock; everything a consumer parses is pinned here.

#include "dbusreports.h"

#include <QJsonDocument>
#include <QTest>

using namespace Latte;
using namespace Latte::DbusReports;

class DbusReportsTest : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void viewTypeNames();
    void edgeNames();
    void alignmentNames();
    void visibilityModeNames();
    void rectSerialization();
    void recordSerialization();
    void emptyInputMaskSerializesAsEmptyRegion();
    void recordsSerializeAsCompactJsonArray();
};

void DbusReportsTest::viewTypeNames()
{
    QCOMPARE(viewTypeName(Types::DockView), QStringLiteral("dock"));
    QCOMPARE(viewTypeName(Types::PanelView), QStringLiteral("panel"));
}

void DbusReportsTest::edgeNames()
{
    QCOMPARE(edgeName(Plasma::Types::BottomEdge), QStringLiteral("bottom"));
    QCOMPARE(edgeName(Plasma::Types::TopEdge), QStringLiteral("top"));
    QCOMPARE(edgeName(Plasma::Types::LeftEdge), QStringLiteral("left"));
    QCOMPARE(edgeName(Plasma::Types::RightEdge), QStringLiteral("right"));
    QCOMPARE(edgeName(Plasma::Types::Floating), QStringLiteral("floating"));
    QCOMPARE(edgeName(Plasma::Types::Desktop), QStringLiteral("desktop"));
    QCOMPARE(edgeName(Plasma::Types::FullScreen), QStringLiteral("fullscreen"));
}

void DbusReportsTest::alignmentNames()
{
    QCOMPARE(alignmentName(Types::NoneAlignment), QStringLiteral("none"));
    QCOMPARE(alignmentName(Types::Center), QStringLiteral("center"));
    QCOMPARE(alignmentName(Types::Left), QStringLiteral("left"));
    QCOMPARE(alignmentName(Types::Right), QStringLiteral("right"));
    QCOMPARE(alignmentName(Types::Top), QStringLiteral("top"));
    QCOMPARE(alignmentName(Types::Bottom), QStringLiteral("bottom"));
    QCOMPARE(alignmentName(Types::Justify), QStringLiteral("justify"));
}

void DbusReportsTest::visibilityModeNames()
{
    QCOMPARE(visibilityModeName(Types::None), QStringLiteral("none"));
    QCOMPARE(visibilityModeName(Types::AlwaysVisible), QStringLiteral("alwaysVisible"));
    QCOMPARE(visibilityModeName(Types::AutoHide), QStringLiteral("autoHide"));
    QCOMPARE(visibilityModeName(Types::DodgeActive), QStringLiteral("dodgeActive"));
    QCOMPARE(visibilityModeName(Types::DodgeMaximized), QStringLiteral("dodgeMaximized"));
    QCOMPARE(visibilityModeName(Types::DodgeAllWindows), QStringLiteral("dodgeAllWindows"));
    QCOMPARE(visibilityModeName(Types::WindowsGoBelow), QStringLiteral("windowsGoBelow"));
    QCOMPARE(visibilityModeName(Types::WindowsCanCover), QStringLiteral("windowsCanCover"));
    QCOMPARE(visibilityModeName(Types::WindowsAlwaysCover), QStringLiteral("windowsAlwaysCover"));
    QCOMPARE(visibilityModeName(Types::SidebarOnDemand), QStringLiteral("sidebarOnDemand"));
    QCOMPARE(visibilityModeName(Types::SidebarAutoHide), QStringLiteral("sidebarAutoHide"));
    QCOMPARE(visibilityModeName(Types::NormalWindow), QStringLiteral("normalWindow"));
}

void DbusReportsTest::rectSerialization()
{
    const QJsonArray json = serializeRect(QRect(10, -20, 300, 44));
    QCOMPARE(json.count(), 4);
    QCOMPARE(json.at(0).toInt(), 10);
    QCOMPARE(json.at(1).toInt(), -20);
    QCOMPARE(json.at(2).toInt(), 300);
    QCOMPARE(json.at(3).toInt(), 44);
}

//! one fully populated record, so every field name and value type a D-Bus
//! consumer parses is pinned against docs/dbus-observability-interface.md
void DbusReportsTest::recordSerialization()
{
    ViewRecord record;
    record.containmentId = 7;
    record.layout = QStringLiteral("My Layout");
    record.isCloned = true;
    record.isClonedFrom = 3;
    record.type = Types::PanelView;
    record.screen = QStringLiteral("DP-2");
    record.onPrimary = true;
    record.edge = Plasma::Types::LeftEdge;
    record.alignment = Types::Justify;
    record.visibilityMode = Types::DodgeMaximized;
    record.isHidden = true;
    record.inStartup = true;
    record.isOffScreen = true;
    record.absoluteGeometry = QRect(1, 2, 3, 4);
    record.localGeometry = QRect(5, 6, 7, 8);
    record.screenGeometry = QRect(0, 0, 2560, 1440);
    record.strutsThickness = 88;
    record.publishedStruts = QRect(0, 1352, 2560, 88);
    record.maskRect = QRect(9, 10, 11, 12);
    record.inputMask = QRect(13, 14, 15, 16);
    record.editMode = true;
    record.inConfigureAppletsMode = true;

    const QJsonObject json = serializeViewRecord(record);

    QCOMPARE(json.value(QStringLiteral("containmentId")).toInt(), 7);
    QCOMPARE(json.value(QStringLiteral("layout")).toString(), QStringLiteral("My Layout"));
    QCOMPARE(json.value(QStringLiteral("isCloned")).toBool(), true);
    QCOMPARE(json.value(QStringLiteral("isClonedFrom")).toInt(), 3);
    QCOMPARE(json.value(QStringLiteral("type")).toString(), QStringLiteral("panel"));
    QCOMPARE(json.value(QStringLiteral("screen")).toString(), QStringLiteral("DP-2"));
    QCOMPARE(json.value(QStringLiteral("onPrimary")).toBool(), true);
    QCOMPARE(json.value(QStringLiteral("edge")).toString(), QStringLiteral("left"));
    QCOMPARE(json.value(QStringLiteral("alignment")).toString(), QStringLiteral("justify"));
    QCOMPARE(json.value(QStringLiteral("visibilityMode")).toString(), QStringLiteral("dodgeMaximized"));
    QCOMPARE(json.value(QStringLiteral("isHidden")).toBool(), true);
    QCOMPARE(json.value(QStringLiteral("inStartup")).toBool(), true);
    QCOMPARE(json.value(QStringLiteral("isOffScreen")).toBool(), true);
    QCOMPARE(json.value(QStringLiteral("absoluteGeometry")).toArray(), serializeRect(QRect(1, 2, 3, 4)));
    QCOMPARE(json.value(QStringLiteral("localGeometry")).toArray(), serializeRect(QRect(5, 6, 7, 8)));
    QCOMPARE(json.value(QStringLiteral("screenGeometry")).toArray(), serializeRect(QRect(0, 0, 2560, 1440)));
    QCOMPARE(json.value(QStringLiteral("strutsThickness")).toInt(), 88);
    QCOMPARE(json.value(QStringLiteral("publishedStruts")).toArray(), serializeRect(QRect(0, 1352, 2560, 88)));
    QCOMPARE(json.value(QStringLiteral("maskRect")).toArray(), serializeRect(QRect(9, 10, 11, 12)));

    const QJsonArray inputRegion = json.value(QStringLiteral("inputRegionRects")).toArray();
    QCOMPARE(inputRegion.count(), 1);
    QCOMPARE(inputRegion.at(0).toArray(), serializeRect(QRect(13, 14, 15, 16)));

    QCOMPARE(json.value(QStringLiteral("editMode")).toBool(), true);
    QCOMPARE(json.value(QStringLiteral("inConfigureAppletsMode")).toBool(), true);
}

//! an invalid/empty input mask means "no input restriction published"
//! (Effects::setInputMask clears the window mask for those) and must read
//! as an empty array, not a degenerate rect
void DbusReportsTest::emptyInputMaskSerializesAsEmptyRegion()
{
    ViewRecord record;
    record.inputMask = QRect(); // default: invalid

    QJsonObject json = serializeViewRecord(record);
    QVERIFY(json.value(QStringLiteral("inputRegionRects")).toArray().isEmpty());

    record.inputMask = QRect(0, 0, -1, -1); // the explicit clear request
    json = serializeViewRecord(record);
    QVERIFY(json.value(QStringLiteral("inputRegionRects")).toArray().isEmpty());
}

void DbusReportsTest::recordsSerializeAsCompactJsonArray()
{
    ViewRecord first;
    first.containmentId = 1;
    ViewRecord second;
    second.containmentId = 2;

    const QString data = serializeViewRecords({first, second});

    //! compact serialization: no newlines, per the interface doc
    QVERIFY(!data.contains(QLatin1Char('\n')));

    QJsonParseError error{};
    const QJsonDocument document = QJsonDocument::fromJson(data.toUtf8(), &error);
    QCOMPARE(error.error, QJsonParseError::NoError);
    QVERIFY(document.isArray());
    QCOMPARE(document.array().count(), 2);
    QCOMPARE(document.array().at(0).toObject().value(QStringLiteral("containmentId")).toInt(), 1);
    QCOMPARE(document.array().at(1).toObject().value(QStringLiteral("containmentId")).toInt(), 2);

    QCOMPARE(serializeViewRecords({}), QStringLiteral("[]"));
}

QTEST_GUILESS_MAIN(DbusReportsTest)
#include "dbusreportstest.moc"
