/*
    SPDX-FileCopyrightText: 2021 Michail Vourlakos <mvourlakos@gmail.com>
    SPDX-FileCopyrightText: 2026 Bree Spektor
    SPDX-License-Identifier: GPL-2.0-or-later
*/

#ifndef CLONEDVIEW_H
#define CLONEDVIEW_H

// local
#include <coretypes.h>
#include "originalview.h"
#include "indicator/indicator.h"
#include "view.h"

// C++
#include <optional>

namespace Latte {

class ClonedView : public View
{
    Q_OBJECT

public:
    static constexpr int ERRORAPPLETID{-999};

    ClonedView(Plasma::Corona *corona,
               Latte::OriginalView *originalView,
               Latte::Data::View::LinkPlacement linkPlacement,
               QScreen *targetScreen = nullptr,
               bool byPassX11WM = false);
    ~ClonedView();

    bool isOriginal() const override;
    bool isCloned() const override;
    bool isSingle() const override;

    bool isPreferredForShortcuts() const override;
    int groupId() const override;

    Latte::Types::ScreensGroup screensGroup() const override;
    Latte::Data::View::LinkPlacement linkPlacement() const override;

    Latte::View *configurationTargetView() override;
    Latte::View *relationshipRootView() override;

    [[nodiscard]] bool addApplet(const QString &pluginId) override;
    [[nodiscard]] bool removeApplet(int appletId) override;
    void synchronizeDroppedApplet(QObject *mimeData, int x, int y) override;

    ViewPart::Indicator *indicator() const override;
    Latte::Data::View data() const override;

protected:
    void showConfigurationInterface(Plasma::Applet *applet) override;

private Q_SLOTS:
    void initSync();
    void onOriginalAppletConfigPropertyChanged(const int &id, const QString &key, const QVariant &value);
    void onOriginalAppletInScheduledDestructionChanged(const int &id, const bool &enabled);
    void onOriginalAppletRemoved(const int &id);
    void onOriginalAppletsOrderChanged();
    void onOriginalAppletsInLockedZoomChanged(const QList<int> &originalapplets);
    void onOriginalAppletsDisabledColoringChanged(const QList<int> &originalapplets);

    void updateContainmentConfigProperty(const QString &key, const QVariant &value);
    void updateOriginalAppletConfigProperty(const int &clonedid, const QString &key, const QVariant &value);
    void updateOriginalAppletsOrder();

    void updateAppletIdsHash();
    void onSyncProgress();
private:
    bool isTranslatableToClonesOrder(const QList<int> &originalOrder) const;

    bool hasOriginalAppletId(const int &clonedid) const;
    int originalAppletId(const int &clonedid) const;

    QList<int> translateToClonesOrder(const QList<int> &originalIds) const;
    QList<int> translateToOriginalsOrder(const QList<int> &clonedIds) const;

    bool applyOriginalAppletsOrder();
    bool applyOriginalAppletsInLockedZoom(const QList<int> &originalapplets);
    bool applyOriginalAppletsDisabledColoring(const QList<int> &originalapplets);
    void retryPendingOriginalSyncs();

private:
    static QStringList CONTAINMENTMANUALSYNCEDPROPERTIES;

    QPointer<Latte::OriginalView> m_originalView;
    const Latte::Data::View::LinkPlacement m_linkPlacement;
    QHash<int, int> m_currentAppletIds;

    //! deferred original->clone syncs (the structuralSyncReady gap): a sync
    //! arriving while the clone is still initializing cannot be translated to
    //! cloned applet ids yet; it is remembered here and retried every time the
    //! ids hash gains entries. Order re-reads the original at apply time, so a
    //! bool suffices; the two list syncs replay their LAST payload, and
    //! optional distinguishes "nothing pending" from a pending EMPTY list
    //! (empty means unlock/recolor everything - a valid payload).
    bool m_pendingOrderSync{false};
    bool m_initializationCompleted{false};
    bool m_applyingOriginalOrder{false};
    std::optional<QList<int>> m_expectedOrderFromOriginal;
    std::optional<QList<int>> m_pendingLockedZoom;
    std::optional<QList<int>> m_pendingDisabledColoring;
};

}

#endif
