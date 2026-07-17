/*
    SPDX-FileCopyrightText: 2026 Bree Spektor
    SPDX-FileCopyrightText: 2026 Latte Dock contributors
    SPDX-License-Identifier: GPL-2.0-or-later
*/

//! Upstream contract (tests/contracts/README.md): libplasma askDestroy()
//! signal ordering at the pinned v6.7.3, earned in 71b0d75a where the System
//! Tray's ghost slot lived exactly as long as the undo window.
//!
//! askDestroy() - the widget-removal entry point behind every applet's
//! "remove" action - marks the applet destroyed() and keeps the OBJECT alive
//! for the undo notification (60s fallback timer). Latte's containment
//! LayoutManager keys its two-phase parking on exactly this timeline, which
//! since 6.7 is the SAME for every applet class:
//!
//! destroyedChanged(true) first, then Containment::appletRemoved fires
//! IMMEDIATELY (synchronously inside askDestroy) with the applet pruned from
//! Containment::applets(), and fires a SECOND time when the object really
//! dies (~Applet emits appletDeleted, which the containment re-broadcasts as
//! appletRemoved - unconditionally, list membership does not gate it).
//! removeAppletItem must treat destroyed()==true as "park, undo still
//! possible" both times. Undo re-inserts into applets() and re-emits
//! appletAdded; addAppletItem tolerates arriving after the destruction
//! watcher already unparked (its "reaches here twice" guard).
//!
//! HISTORY - the 6.6.5 contract this test originally pinned: askDestroy()
//! guarded the immediate emit AND the list removal with !isContainment(),
//! so a containment-type applet (the System Tray is a Plasma::Containment
//! of type CustomEmbedded) got NO immediate appletRemoved, stayed in
//! applets() for the whole undo window, and its ONLY appletRemoved arrived
//! at object death. libplasma 6.7 widened the guard to
//! `containment() && containment() != q` (both in askDestroy's tail and in
//! the undo re-add), so CustomEmbedded trays now follow the plain-applet
//! ordering exactly. Latte's parking survives the change by construction -
//! setAppletInScheduledDestruction is idempotent per id in both directions,
//! and the AppletItem.qml destruction watcher (which parks on
//! destroyedChanged and is now redundant-but-first for parking) remains the
//! unpark-before-appletAdded ordering guarantee on undo. Caught by this
//! test at the 2026-07-17 re-pin.
//!
//! The undo window's end is simulated with a direct delete: the real timer
//! path (AppletPrivate::cleanUpAndDelete) ends in deleteLater() on the same
//! object, and the appletRemoved-at-death emission under test lives in
//! ~Applet -> appletDeleted -> ContainmentPrivate::appletDeleted, which both
//! paths share.
//!
//! Constructed offscreen: Plasma::Corona, Plasma::Containment and
//! Plasma::Applet all have public constructors; the applet id rides in
//! args[1]. The Corona is not optional decoration: Applet::isContainment()
//! is true only for a Containment whose parent IS a Corona (or one of type
//! CustomEmbedded), and both the askDestroy() emit guard and
//! Containment::init() key off it. askDestroy() is a Q_PRIVATE_SLOT,
//! reachable through the metaobject exactly as the remove QAction reaches
//! it.

// Qt
#include <QJsonObject>
#include <QPointer>
#include <QSignalSpy>
#include <QStandardPaths>
#include <QtTest>

// KDE
#include <KPluginMetaData>

// Plasma
#include <Plasma/Applet>
#include <Plasma/Containment>
#include <Plasma/Corona>
#include <Plasma/plasma_version.h>

//! Corona's one pure virtual is screenGeometry(); everything else works
//! offscreen as-is
class TestCorona : public Plasma::Corona
{
    Q_OBJECT

public:
    using Plasma::Corona::Corona;

    QRect screenGeometry(int id) const override
    {
        Q_UNUSED(id);
        return QRect(0, 0, 1920, 1080);
    }
};

class AskDestroySignalOrderingTest : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void initTestCase();
    void plainAppletRemovedImmediatelyAndAgainAtDeath();
    void containmentTypeAppletRemovedImmediatelyAndAgainAtDeath();

private:
    Plasma::Containment *createHostContainment(Plasma::Corona *corona);
    static void startApplet(Plasma::Applet *applet);
    static bool invokeAskDestroy(Plasma::Applet *applet);
};

void AskDestroySignalOrderingTest::initTestCase()
{
    //! keep every config write in throwaway test paths
    QStandardPaths::setTestModeEnabled(true);

    //! askDestroy() posts a real "Widget Removed" KNotification. Point the
    //! session bus somewhere unconnectable BEFORE anything touches DBus, so
    //! a ctest run never pops notifications on the developer's desktop and
    //! the test cannot depend on a session bus being present.
    qputenv("DBUS_SESSION_BUS_ADDRESS", "unix:path=/dev/null");
}

Plasma::Containment *AskDestroySignalOrderingTest::createHostContainment(Plasma::Corona *corona)
{
    //! valid metadata is required: Containment derives its type from
    //! X-Plasma-ContainmentType at construction. Panel matches Latte's dock
    //! containment. The Corona parent is what makes isContainment() true.
    QJsonObject json{
        {QStringLiteral("KPlugin"),
         QJsonObject{{QStringLiteral("Id"), QStringLiteral("test.latte.hostcontainment")}, {QStringLiteral("Name"), QStringLiteral("Host Containment")}}},
        {QStringLiteral("X-Plasma-ContainmentType"), QStringLiteral("Panel")},
    };
    KPluginMetaData md(json, QString());

    auto *host = new Plasma::Containment(corona, md, {QVariant(), QVariant(1)});
    startApplet(host);
    return host;
}

void AskDestroySignalOrderingTest::startApplet(Plasma::Applet *applet)
{
    //! askDestroy() refuses to run before the applet is started; the corona
    //! normally delivers this constraint at startup
    applet->updateConstraints(Plasma::Applet::StartupCompletedConstraint);

    //! setDestroyed() writes the "transient" entry through the lazily
    //! created main config group without materializing it first; in a real
    //! shell the restore path has always done that by removal time. Touch
    //! config() once so the test reaches askDestroy in the same state.
    applet->config();
}

bool AskDestroySignalOrderingTest::invokeAskDestroy(Plasma::Applet *applet)
{
    return QMetaObject::invokeMethod(applet, "askDestroy", Qt::DirectConnection);
}

void AskDestroySignalOrderingTest::plainAppletRemovedImmediatelyAndAgainAtDeath()
{
    TestCorona corona;
    Plasma::Containment *host = createHostContainment(&corona);
    QVERIFY(host->isContainment());

    //! invalid metadata is the plain-applet shape with the least machinery;
    //! id rides in args[1]
    auto *applet = new Plasma::Applet(host, KPluginMetaData(), {QVariant(), QVariant(7)});
    host->addApplet(applet);
    startApplet(applet);

    QVERIFY(host->applets().contains(applet));
    QVERIFY(!applet->destroyed());

    QSignalSpy removedSpy(host, &Plasma::Containment::appletRemoved);
    QSignalSpy destroyedChangedSpy(applet, &Plasma::Applet::destroyedChanged);
    QPointer<Plasma::Applet> alive(applet);

    QVERIFY(invokeAskDestroy(applet));

    QVERIFY2(applet->destroyed(), "askDestroy must mark the applet destroyed() for the undo window");
    QCOMPARE(destroyedChangedSpy.count(), 1);
    QCOMPARE(destroyedChangedSpy.at(0).at(0).toBool(), true);

    QVERIFY2(removedSpy.count() == 1, "plain applets must get appletRemoved IMMEDIATELY (synchronously) from askDestroy - "
                                       "LayoutManager::removeAppletItem parks on this call");
    QVERIFY2(!host->applets().contains(applet), "askDestroy prunes plain applets from Containment::applets() immediately");
    QVERIFY2(!alive.isNull(), "the applet OBJECT must survive askDestroy: it is the undo window");

    //! the undo window ends: the object dies, and the containment
    //! re-broadcasts appletRemoved a SECOND time from appletDeleted.
    //! LayoutManager::removeAppletItem runs again here and must see
    //! destroyed() still true (it no-ops on the already-parked id).
    delete applet;
    QVERIFY2(removedSpy.count() == 2, "appletRemoved must fire again at object death; if this stops, the parked-entry "
                                       "pruning in setAppletInScheduledDestruction is the only cleanup left");

    delete host;
}

void AskDestroySignalOrderingTest::containmentTypeAppletRemovedImmediatelyAndAgainAtDeath()
{
    TestCorona corona;
    Plasma::Containment *host = createHostContainment(&corona);

    //! the System Tray shape: an applet that IS a Plasma::Containment of
    //! type CustomEmbedded
    QJsonObject json{
        {QStringLiteral("KPlugin"),
         QJsonObject{{QStringLiteral("Id"), QStringLiteral("test.latte.embeddedtray")}, {QStringLiteral("Name"), QStringLiteral("Embedded Tray")}}},
        {QStringLiteral("X-Plasma-ContainmentType"), QStringLiteral("CustomEmbedded")},
    };
    KPluginMetaData md(json, QString());

    auto *tray = new Plasma::Containment(host, md, {QVariant(), QVariant(8)});
    host->addApplet(tray);
    startApplet(tray);

    QVERIFY(tray->isContainment());
    QVERIFY(host->applets().contains(tray));

    QSignalSpy removedSpy(host, &Plasma::Containment::appletRemoved);
    QSignalSpy destroyedChangedSpy(tray, &Plasma::Applet::destroyedChanged);
    QPointer<Plasma::Applet> alive(tray);

    QVERIFY(invokeAskDestroy(tray));

    //! destroyedChanged(true) still arrives FIRST - the AppletItem.qml
    //! destruction watcher parks on it (71b0d75a) before removeAppletItem
    //! ever runs, and setAppletInScheduledDestruction's per-id idempotence
    //! is what makes the second park attempt below a no-op
    QVERIFY(tray->destroyed());
    QCOMPARE(destroyedChangedSpy.count(), 1);
    QCOMPARE(destroyedChangedSpy.at(0).at(0).toBool(), true);

    //! The immediate-emit + applets()-prune half of the contract SPLIT at
    //! libplasma 6.7, so pin whichever the SUBSTRATE actually ships. The
    //! project floor is Plasma 6.5 (CMakeLists PLASMA_MIN_VERSION), and the
    //! deb-family legs run below 6.7 (Debian testing ships libplasma 6.6.5),
    //! so hardcoding only the 6.7 shape turned this into a version-skew
    //! failure off the 6.7.3 dev pin (caught live in the Debian container).
    //! Latte's parking is idempotent in both directions and survives either
    //! ordering by construction, so the two branches keep this a real
    //! contract check on every supported substrate instead of a false red.
#if PLASMA_VERSION >= ((6 << 16) | (7 << 8) | 0)
    //! 6.7+ contract: containment-type applets now get the SAME immediate
    //! emit and applets() prune as plain applets (the pre-6.7 !isContainment()
    //! guard became `containment() != q`); removeAppletItem runs here with
    //! destroyed()==true and must park idempotently, not double-handle
    QVERIFY2(removedSpy.count() == 1, "containment-type applets must get appletRemoved IMMEDIATELY since libplasma 6.7 "
                                       "(guard widened to containment() != q) - a count of 0 means the substrate reverted "
                                       "to the pre-6.7 !isContainment() behavior and the parking timeline moved again");
    QVERIFY2(!host->applets().contains(tray), "since 6.7 askDestroy prunes containment-type applets from Containment::applets() "
                                              "immediately, same as plain applets");
    QVERIFY(!alive.isNull());

    //! object death re-broadcasts appletRemoved a second time
    //! (ContainmentPrivate::appletDeleted emits without checking list
    //! membership); removeAppletItem must no-op on the already-parked id
    delete tray;
    QVERIFY2(removedSpy.count() == 2, "appletRemoved must fire again at the containment-type applet's object death; "
                                       "removeAppletItem finalizes nothing before this");
#else
    //! pre-6.7 contract (Debian testing's libplasma 6.6.5): askDestroy guards
    //! the immediate emit AND the applets() prune with !isContainment(), so a
    //! containment-type applet gets NO immediate appletRemoved and stays in
    //! applets() for the whole undo window - its ONLY appletRemoved arrives at
    //! object death (the HISTORY block above documents this exact shape)
    QVERIFY2(removedSpy.count() == 0, "pre-6.7 libplasma gives containment-type applets NO immediate appletRemoved - "
                                       "askDestroy's emit is guarded !isContainment(); a count of 1 means the substrate "
                                       "already carries the 6.7 widened guard and PLASMA_VERSION mis-selected this branch");
    QVERIFY2(host->applets().contains(tray), "pre-6.7 askDestroy leaves containment-type applets in Containment::applets() "
                                             "for the whole undo window");
    QVERIFY(!alive.isNull());

    //! object death delivers the single appletRemoved
    //! (ContainmentPrivate::appletDeleted emits regardless of list membership)
    delete tray;
    QVERIFY2(removedSpy.count() == 1, "pre-6.7 the containment-type applet's ONLY appletRemoved arrives at object death");
#endif

    delete host;
}

QTEST_MAIN(AskDestroySignalOrderingTest)

#include "askdestroysignalorderingtest.moc"
