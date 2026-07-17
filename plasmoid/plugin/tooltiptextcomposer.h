/*
    SPDX-FileCopyrightText: 2026 Bree Spektor
    SPDX-FileCopyrightText: 2026 Latte Dock contributors
    SPDX-License-Identifier: GPL-2.0-or-later

    Latte-authored, NOT part of the plasma-desktop vendored set in this
    directory (see plasmoid/plugin/units/README.md).
*/

#ifndef TOOLTIPTEXTCOMPOSER_H
#define TOOLTIPTEXTCOMPOSER_H

// Qt
#include <QObject>
#include <QString>
#include <QVariantMap>

namespace Latte {
namespace Tasks {

//! Thin QML shell over the TooltipText core (EX-17): the stateless
//! LatteTasks.TooltipTextComposer singleton the preview tooltip shells
//! call. The core decides (units/tooltiptext.h); this wrapper converts
//! the QML fact bag, refuses malformed calls loudly, and maps the plan
//! onto the i18nc strings - translation is presentation, and the catalog
//! lookup is ambient state the pure core must not read. The i18nc
//! context/message pairs moved here verbatim from the QML bodies; they
//! stay in the plasma_applet_org.kde.latte.plasmoid domain
//! (plasmoid/CMakeLists.txt defines it for this plugin, and
//! plasmoid/Messages.sh extracts .cpp files).
class TooltipTextComposer : public QObject
{
    Q_OBJECT

public:
    explicit TooltipTextComposer(QObject *parent = nullptr);

    Q_INVOKABLE QString composeTitle(const QString &display, const QString &appName) const;

    //! facts keys (all required): showOnlyCurrentDesktop,
    //! showOnlyCurrentActivity, desktopCount, runningActivityCount,
    //! onAllVirtualDesktops, desktopNames, activityIds, activityNames,
    //! currentActivity. activityIds/activityNames are null together (the
    //! Activities role is unknown) or equal-length lists.
    Q_INVOKABLE QString composeSubText(const QVariantMap &facts) const;

    //! Phase 10 AT-SPI rollout: the Accessible.description a task item
    //! reports - group size and badge state, composed from what the item
    //! currently SHOWS (the shell resolves badge visibility; see
    //! AccessibleDescriptionFacts in units/tooltiptext.h). facts keys
    //! (all required): isLauncher, isGroupParent, windowsCount,
    //! showsAudioBadge, isMuted, showsProgressBadge, progressPercent,
    //! infoBadgeCount.
    Q_INVOKABLE QString composeAccessibleDescription(const QVariantMap &facts) const;

    //! The audio badge's accessible name. Lives here, not as a QML i18n
    //! call, for the same reason as every composed string: the qmllint
    //! ratchet holds new package QML at zero unqualified accesses, and
    //! i18n resolves through the context chain. Same msgid and catalog
    //! as the context menu's checkable Mute item, so a screen reader
    //! announces the badge and the menu item identically.
    Q_INVOKABLE QString muteToggleLabel() const;
};

}
}

#endif
