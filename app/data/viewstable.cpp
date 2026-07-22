/*
    SPDX-FileCopyrightText: 2021 Michail Vourlakos <mvourlakos@gmail.com>
    SPDX-FileCopyrightText: 2026 Bree Spektor
    SPDX-License-Identifier: GPL-2.0-or-later
*/

#include "viewstable.h"

#include <QDebug>
#include <QSet>

namespace Latte {
namespace Data {

const char *TEMPIDPREFIX = "temp:";

ViewsTable::ViewsTable()
    : GenericTable<View>()
{
}

ViewsTable::ViewsTable(ViewsTable &&o)
    : GenericTable<View>(o),
      isInitialized(o.isInitialized)
{

}

ViewsTable::ViewsTable(const ViewsTable &o)
    : GenericTable<View>(o),
      isInitialized(o.isInitialized)
{
}

//! Operators
ViewsTable &ViewsTable::operator=(const ViewsTable &rhs)
{
    m_list = rhs.m_list;
    isInitialized = rhs.isInitialized;
    return (*this);
}

ViewsTable &ViewsTable::operator=(ViewsTable &&rhs)
{
    m_list = rhs.m_list;
    isInitialized = rhs.isInitialized;
    return (*this);
}

bool ViewsTable::operator==(const ViewsTable &rhs) const
{
    GenericTable<View> tempView = (*this);

    return (isInitialized == rhs.isInitialized)
            && (((GenericTable<View>)*this) == ((GenericTable<View>)rhs));
}

bool ViewsTable::operator!=(const ViewsTable &rhs) const
{
    return !(*this == rhs);
}

bool ViewsTable::hasContainmentId(const QString &cid) const
{
    if (containsId(cid)) {
        return true;
    }

    for(int i=0; i<rowCount(); ++i) {
        if (m_list[i].subcontainments.containsId(cid)) {
            return true;
        }
    }

    return false;
}

QString ViewsTable::relationshipValidationError() const
{
    QSet<QString> identities;
    identities.reserve(rowCount());

    for (const auto &view : m_list) {
        if (!view.isValid() || view.id.isEmpty()) {
            return QStringLiteral("a persisted dock record is invalid or has no containment identity");
        }

        if (identities.contains(view.id)) {
            return QStringLiteral("dock containment identity %1 is duplicated").arg(view.id);
        }
        identities.insert(view.id);

        if (!view.hasValidLinkPlacement()) {
            return QStringLiteral("dock %1 has an invalid linked-placement value").arg(view.id);
        }

        if (!view.isCloned()
                && view.linkPlacement != View::LinkPlacement::ScreenGroupDerived) {
            return QStringLiteral("independent dock %1 claims linked-member placement").arg(view.id);
        }
    }

    for (const auto &member : m_list) {
        if (!member.isCloned()) {
            continue;
        }

        if (member.isClonedFrom <= 0) {
            return QStringLiteral("linked dock %1 has invalid root identity %2")
                .arg(member.id)
                .arg(member.isClonedFrom);
        }

        const QString rootId = QString::number(member.isClonedFrom);
        if (member.id == rootId) {
            return QStringLiteral("linked dock %1 references itself as its root").arg(member.id);
        }
        if (!containsId(rootId)) {
            return QStringLiteral("linked dock %1 references missing root %2")
                .arg(member.id, rootId);
        }

        const View root = (*this)[rootId];
        if (root.isCloned()) {
            return QStringLiteral("linked dock %1 references non-root dock %2")
                .arg(member.id, rootId);
        }
        if (root.linkPlacement != View::LinkPlacement::ScreenGroupDerived) {
            return QStringLiteral("linked dock %1 references malformed root %2")
                .arg(member.id, rootId);
        }
    }

    return {};
}

ViewsTable ViewsTable::subtracted(const ViewsTable &rhs) const
{
    ViewsTable subtract;

    if ((*this) == rhs) {
        return subtract;
    }

    for(int i=0; i<m_list.count(); ++i) {
        if (!rhs.containsId(m_list[i].id)) {
            subtract << m_list[i];
        }
    }

    return subtract;
}

ViewsTable ViewsTable::onlyOriginals() const
{
    ViewsTable originals;

    for(int i=0; i<m_list.count(); ++i) {
        if (m_list[i].isOriginal()) {
            originals << m_list[i];
        }
    }

    return originals;
}

void ViewsTable::appendTemporaryView(const Data::View &view)
{
    int maxTempId = 0;

    for(int i=0; i<rowCount(); ++i) {
        if ((*this)[i].id.startsWith(TEMPIDPREFIX)) {
            QString tid = (*this)[i].id;
            tid.remove(0, QString(TEMPIDPREFIX).count());
            if (tid.toInt() > maxTempId) {
                maxTempId = tid.toInt();
            }
        }
    }

    Data::View newview = view;
    newview.id =  QString(TEMPIDPREFIX + QString::number(maxTempId+1));
    m_list << newview;
}

void ViewsTable::print()
{
    qDebug().noquote() << "Views initialized : " + (isInitialized ? QString("true") : QString("false"));
    qDebug().noquote() << "aa | id | active | primary | screen | edge | alignment | maxlength | subcontainments";

    for(int i=0; i<rowCount(); ++i) {
        qDebug().noquote() << QString::number(i+1) << " | " << m_list[i];
    }
}

}
}
