/*
    SPDX-FileCopyrightText: 2026 Bree Spektor
    SPDX-FileCopyrightText: 2026 Latte Dock contributors
    SPDX-License-Identifier: GPL-2.0-or-later
*/

#include "filldistributortools.h"

// local
#include "units/filldistributor.h"

// Qt
#include <QDebug>

namespace Latte {

FillDistributorTools::FillDistributorTools(QObject *parent)
    : QObject(parent)
{
}

namespace {

bool readLayoutSnapshot(const QVariantMap &layout, const char *name, FillDistributor::LayoutSnapshot &out)
{
    for (const char *key : {"items", "sizeWithNoFill", "fillApplets", "shownApplets", "gridLength"}) {
        if (!layout.contains(QLatin1String(key))) {
            //! a malformed snapshot is a shell bug, never something to
            //! distribute around silently
            qCritical() << "FillDistributor.distribute:" << name << "layout misses key" << key << "- refusing to distribute";
            return false;
        }
    }

    out.sizeWithNoFillApplets = layout.value(QStringLiteral("sizeWithNoFill")).toDouble();
    out.fillApplets = layout.value(QStringLiteral("fillApplets")).toInt();
    out.shownApplets = layout.value(QStringLiteral("shownApplets")).toInt();
    out.gridLength = layout.value(QStringLiteral("gridLength")).toDouble();

    if (out.fillApplets < 0 || out.shownApplets < 0) {
        qCritical() << "FillDistributor.distribute:" << name << "layout carries a negative counter"
                    << out.fillApplets << out.shownApplets << "- refusing to distribute";
        return false;
    }

    const QVariantList items = layout.value(QStringLiteral("items")).toList();
    out.items.reserve(items.size());
    for (const QVariant &entry : items) {
        const QVariantMap map = entry.toMap();
        for (const char *key : {"autoFill", "hidden", "hasApplet", "splitter", "min", "pref", "max", "liveMax", "liveMin"}) {
            if (!map.contains(QLatin1String(key))) {
                qCritical() << "FillDistributor.distribute:" << name << "item misses key" << key << "- refusing to distribute";
                return false;
            }
        }

        FillDistributor::FillItem item;
        item.autoFill = map.value(QStringLiteral("autoFill")).toBool();
        item.hidden = map.value(QStringLiteral("hidden")).toBool();
        item.hasApplet = map.value(QStringLiteral("hasApplet")).toBool();
        item.internalSplitter = map.value(QStringLiteral("splitter")).toBool();
        item.minLength = map.value(QStringLiteral("min")).toDouble();
        item.prefLength = map.value(QStringLiteral("pref")).toDouble();
        item.maxLength = map.value(QStringLiteral("max")).toDouble();
        item.liveMaxFillLength = map.value(QStringLiteral("liveMax")).toDouble();
        item.liveMinFillLength = map.value(QStringLiteral("liveMin")).toDouble();
        out.items.append(item);
    }

    return true;
}

QVariantList toVariantAssignments(const QVector<FillDistributor::ItemAssignment> &assignments)
{
    QVariantList out;
    out.reserve(assignments.size());
    for (const FillDistributor::ItemAssignment &assignment : assignments) {
        QVariantMap entry;
        //! absent keys mean "untouched, keep the previous value" - the
        //! applier writes only what a pass actually assigned
        if (assignment.maxFillLength) {
            entry.insert(QStringLiteral("max"), *assignment.maxFillLength);
        }
        if (assignment.minFillLength) {
            entry.insert(QStringLiteral("min"), *assignment.minFillLength);
        }
        out.append(entry);
    }
    return out;
}

}

QVariantMap FillDistributorTools::distribute(const QVariantMap &start, const QVariantMap &main, const QVariantMap &end,
                                             bool justifyAlignment, double minLength, double contentsMaxLength)
{
    FillDistributor::Snapshot snapshot;
    if (!readLayoutSnapshot(start, "start", snapshot.start)
            || !readLayoutSnapshot(main, "main", snapshot.main)
            || !readLayoutSnapshot(end, "end", snapshot.end)) {
        return QVariantMap();
    }

    snapshot.alignment = justifyAlignment ? FillDistributor::Alignment::Justify : FillDistributor::Alignment::NonJustify;
    snapshot.minLength = minLength;
    snapshot.contentsMaxLength = contentsMaxLength;

    const FillDistributor::Assignments assignments = FillDistributor::distributeFillLengths(snapshot);

    QVariantMap out;
    out.insert(QStringLiteral("start"), toVariantAssignments(assignments.start));
    out.insert(QStringLiteral("main"), toVariantAssignments(assignments.main));
    out.insert(QStringLiteral("end"), toVariantAssignments(assignments.end));
    return out;
}

}
