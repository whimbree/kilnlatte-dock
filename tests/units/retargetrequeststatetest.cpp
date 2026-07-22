/*
    SPDX-FileCopyrightText: 2026 Bree Spektor
    SPDX-FileCopyrightText: 2026 Latte Dock contributors

    SPDX-License-Identifier: GPL-2.0-or-later
*/

#include "../../app/view/settings/retargetrequeststate.h"

#include <QtTest>

using Latte::ViewPart::RetargetRequestState;

class RetargetRequestStateTest : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void onlyNewestRequestCanBeConsumed();
    void canceledRequestCannotBeConsumed();
    void requestCanBeConsumedOnlyOnce();
    void pendingTargetCanBeCanceledBeforeTimeout();
};

void RetargetRequestStateTest::onlyNewestRequestCanBeConsumed()
{
    RetargetRequestState state;
    const auto first = state.beginRequest(1);
    const auto second = state.beginRequest(2);

    QVERIFY(!state.consumeIfCurrent(first));
    QVERIFY(state.consumeIfCurrent(second));
}

void RetargetRequestStateTest::canceledRequestCannotBeConsumed()
{
    RetargetRequestState state;
    const auto request = state.beginRequest(1);

    state.cancelRequest();

    QVERIFY(!state.consumeIfCurrent(request));
}

void RetargetRequestStateTest::requestCanBeConsumedOnlyOnce()
{
    RetargetRequestState state;
    const auto request = state.beginRequest(1);

    QVERIFY(state.consumeIfCurrent(request));
    QVERIFY(!state.consumeIfCurrent(request));
}

void RetargetRequestStateTest::pendingTargetCanBeCanceledBeforeTimeout()
{
    RetargetRequestState state;
    const auto request = state.beginRequest(42);

    QVERIFY(state.isTargetPending(42));
    QVERIFY(!state.isTargetPending(41));

    state.cancelRequest();

    QVERIFY(!state.isTargetPending(42));
    QVERIFY(!state.consumeIfCurrent(request));
}

QTEST_GUILESS_MAIN(RetargetRequestStateTest)

#include "retargetrequeststatetest.moc"
