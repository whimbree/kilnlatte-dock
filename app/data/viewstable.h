/*
    SPDX-FileCopyrightText: 2020 Michail Vourlakos <mvourlakos@gmail.com>
    SPDX-FileCopyrightText: 2026 Bree Spektor
    SPDX-License-Identifier: GPL-2.0-or-later
*/

#ifndef VIEWSTABLEDATA_H
#define VIEWSTABLEDATA_H

// local
#include "generictable.h"
#include "viewdata.h"

// Qt
#include <QList>

namespace Latte {
namespace Data {

class ViewsTable : public GenericTable<View>
{

public:
    ViewsTable();
    ViewsTable(ViewsTable &&o);
    ViewsTable(const ViewsTable &o);

    bool isInitialized{false};

    void print();

    void appendTemporaryView(const Data::View &view);

    bool hasContainmentId(const QString &cid) const;

    [[nodiscard]] int linkedMembersCount(const QString &rootId) const;
    [[nodiscard]] int explicitLinkedMembersCount(const QString &rootId) const;

    //! Explicit members are persistent relationship records. A root cannot be
    //! removed or moved as one Plasma containment transaction while any of
    //! these records remain because the operation would strand part of the
    //! relationship.
    [[nodiscard]] bool hasExplicitLinkedMembers(const QString &rootId) const;

    //! Only an independent root, or a root whose members are all
    //! screen-group-derived, can cross a layout boundary through the legacy
    //! per-containment move transaction.
    [[nodiscard]] bool allowsMoveToAnotherLayout(const QString &viewId) const;

    //! A legacy All Screens move is coordinated as one root request followed
    //! by one internal move for each screen-group-derived member. Explicit
    //! members never participate in that transaction.
    [[nodiscard]] bool participatesInLegacyLayoutMove(const QString &viewId) const;

    //! Empty means that every linked member names a present direct root.
    //! Persisted chains, cycles, missing roots, and duplicate identities are
    //! rejected before any runtime view is constructed.
    [[nodiscard]] QString relationshipValidationError() const;

    //! Operators
    ViewsTable &operator=(const ViewsTable &rhs);
    ViewsTable &operator=(ViewsTable &&rhs);
    bool operator==(const ViewsTable &rhs) const;
    bool operator!=(const ViewsTable &rhs) const;
    ViewsTable subtracted(const ViewsTable &rhs) const;
    ViewsTable onlyOriginals() const;
};

}
}

Q_DECLARE_METATYPE(Latte::Data::ViewsTable)

#endif
