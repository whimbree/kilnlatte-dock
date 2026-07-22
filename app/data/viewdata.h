/*
    SPDX-FileCopyrightText: 2021 Michail Vourlakos <mvourlakos@gmail.com>
    SPDX-FileCopyrightText: 2026 Bree Spektor
    SPDX-License-Identifier: GPL-2.0-or-later
*/

#ifndef VIEWDATA_H
#define VIEWDATA_H

// local
#include <coretypes.h>
#include "genericdata.h"
#include "../screenpool.h"

// Qt
#include <QMetaType>
#include <QString>

// Plasma
#include <Plasma/Plasma>


namespace Latte {
namespace Data {

class View : public Generic
{
public:
    enum class LinkPlacement {
        ScreenGroupDerived = 0,
        ExplicitTarget,
    };

    enum State {
        IsInvalid = -1,
        IsCreated = 0,
        OriginFromViewTemplate, /*used for view templates files*/
        OriginFromLayout /*used from duplicate, copy, move view functions*/
    };

    static const int ISCLONEDNULL;

    View();
    View(View &&o);
    View(const View &o);
    View(const QString &newid, const QString &newname);

    //! View data
    bool isActive{false};
    bool onPrimary{true};
    int isClonedFrom{ISCLONEDNULL};
    int screen{Latte::ScreenPool::FIRSTSCREENID};
    int screenEdgeMargin{0};
    float maxLength{1.0};
    Plasma::Types::Location edge{Plasma::Types::BottomEdge};
    Latte::Types::Alignment alignment{Latte::Types::Center};
    Latte::Types::ScreensGroup screensGroup{Latte::Types::SingleScreenGroup};
    LinkPlacement linkPlacement{LinkPlacement::ScreenGroupDerived};
    GenericTable<Data::Generic> subcontainments;

    int errors{0};
    int warnings{0};

    //! View sub-states
    bool isMoveOrigin{false};
    bool isMoveDestination{false};

    bool isValid() const;
    bool isCreated() const;
    bool isOriginal() const;
    bool isCloned() const;
    bool isScreenGroupReplica() const;
    bool isExplicitlyLinked() const;
    bool hasValidLinkPlacement() const;
    bool hasViewTemplateOrigin() const;
    bool hasLayoutOrigin() const;
    bool hasSubContainment(const QString &subId) const;
    bool hasErrors() const;
    bool hasWarnings() const;

    bool isHorizontal() const;
    bool isVertical() const;

    [[nodiscard]] View toIndependentSnapshot() const;
    [[nodiscard]] View toExplicitLinkedMember(int relationshipRootId,
                                              int targetScreenId,
                                              Plasma::Types::Location targetEdge) const;

    [[nodiscard]] static constexpr Latte::Types::Alignment normalizeAlignmentForEdge(
        Latte::Types::Alignment sourceAlignment,
        Plasma::Types::Location targetEdge) noexcept
    {
        const bool targetIsVertical = targetEdge == Plasma::Types::LeftEdge
                || targetEdge == Plasma::Types::RightEdge;

        switch (sourceAlignment) {
        case Latte::Types::Left:
        case Latte::Types::Top:
            return targetIsVertical ? Latte::Types::Top : Latte::Types::Left;
        case Latte::Types::Right:
        case Latte::Types::Bottom:
            return targetIsVertical ? Latte::Types::Bottom : Latte::Types::Right;
        case Latte::Types::Center:
        case Latte::Types::Justify:
        case Latte::Types::NoneAlignment:
            return sourceAlignment;
        }

        return Latte::Types::NoneAlignment;
    }

    QString originFile() const;
    QString originLayout() const;
    QString originView() const;    

    View::State state() const;
    void setState(View::State state, QString file = QString(), QString layout = QString(), QString view = QString());

    //! Operators
    View &operator=(const View &rhs);
    View &operator=(View &&rhs);
    bool operator==(const View &rhs) const;
    bool operator!=(const View &rhs) const;
    operator QString() const;

protected:
    View::State m_state{IsInvalid};

    //! Origin Data
    QString m_originFile;
    QString m_originLayout;
    QString m_originView;
};

}
}

Q_DECLARE_METATYPE(Latte::Data::View)

#endif
