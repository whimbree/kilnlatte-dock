/*
    SPDX-FileCopyrightText: 2026 Bree Spektor
    SPDX-FileCopyrightText: 2026 Latte Dock contributors

    SPDX-License-Identifier: GPL-2.0-or-later
*/

//! Pins the Qt teardown semantics the Corona's shutdown sequence is designed
//! around (read from qtbase 6.11.0 qcoreapplication.cpp: exec(), exit(),
//! QCoreApplicationPrivate::execCleanup()):
//!
//! 1. aboutToQuit is emitted synchronously INSIDE exit()/quit(), before the
//!    event loop unwinds - so Corona::onAboutToQuit runs with a fully live
//!    application (views can hide, config can sync, D-Bus is still up).
//! 2. execCleanup() flushes DeferredDelete events once, after the loop
//!    returns - a deleteLater() posted from an aboutToQuit handler IS
//!    honored before exec() returns to main().
//! 3. a deleteLater() posted after exec() returned is never processed:
//!    no loop remains to flush it and the object leaks silently. This is
//!    why ~Corona deletes its members explicitly in dependency order - the
//!    pre-fix destructor's pile of deleteLater() calls did nothing and left
//!    the real destruction to ~QObject's child pass, which deletes in
//!    CONSTRUCTION order: screen/theme services first, the layouts manager
//!    whose teardown still consumed them last (the crash-on-logout class).
//!
//! If a Qt pin bump fails any of these, the teardown ordering in ~Corona
//! and Corona::onAboutToQuit must be re-audited before the bump lands.

#include <QCoreApplication>
#include <QPointer>
#include <QTimer>
#include <QtTest>

class QuitTeardownContractsTest : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void aboutToQuitRunsBeforeExecReturns();
    void deleteLaterFromAboutToQuitIsFlushed();
    void deleteLaterAfterExecIsNeverProcessed();
};

void QuitTeardownContractsTest::aboutToQuitRunsBeforeExecReturns()
{
    bool aboutToQuitRan = false;
    bool execReturned = false;

    auto connection = connect(qApp, &QCoreApplication::aboutToQuit, this, [&]() {
        aboutToQuitRan = true;
        //! emitted from inside exit(), while exec() is still on the stack
        QVERIFY(!execReturned);
    });

    QTimer::singleShot(0, qApp, &QCoreApplication::quit);
    qApp->exec();
    execReturned = true;
    disconnect(connection);

    QVERIFY(aboutToQuitRan);
}

void QuitTeardownContractsTest::deleteLaterFromAboutToQuitIsFlushed()
{
    QPointer<QObject> victim = new QObject;

    auto connection = connect(qApp, &QCoreApplication::aboutToQuit, this, [victim]() {
        if (victim) {
            victim->deleteLater();
        }
    });

    QTimer::singleShot(0, qApp, &QCoreApplication::quit);
    qApp->exec();
    disconnect(connection);

    //! execCleanup() flushed the deferred delete before exec() returned
    QVERIFY(victim.isNull());
}

void QuitTeardownContractsTest::deleteLaterAfterExecIsNeverProcessed()
{
    QTimer::singleShot(0, qApp, &QCoreApplication::quit);
    qApp->exec();

    //! main() is past exec() now, exactly where ~Corona runs in the app
    QPointer<QObject> victim = new QObject;
    victim->deleteLater();

    //! nothing flushes the posted event anymore; the object survives (in
    //! the real app: leaks, destructor never runs, teardown never happens)
    QVERIFY(!victim.isNull());

    //! manual delete also removes the stale posted event for the object
    delete victim.data();
}

QTEST_GUILESS_MAIN(QuitTeardownContractsTest)
#include "quitteardowncontractstest.moc"
