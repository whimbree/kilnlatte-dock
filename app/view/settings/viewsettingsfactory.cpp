/*
    SPDX-FileCopyrightText: 2020 Michail Vourlakos <mvourlakos@gmail.com>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

#include "viewsettingsfactory.h"

// local
#include "primaryconfigview.h"
#include "widgetexplorerview.h"
#include "../view.h"

// Plasma
#include <Plasma/Containment>

namespace Latte {

ViewSettingsFactory::ViewSettingsFactory(QObject *parent)
    : QObject(parent)
{
}

ViewSettingsFactory::~ViewSettingsFactory()
{
    if (m_primaryConfigView) {
        delete m_primaryConfigView;
    }
}

bool ViewSettingsFactory::hasOrphanSettings() const
{
    return m_primaryConfigView && !m_primaryConfigView->parentView();
}

bool ViewSettingsFactory::hasVisibleSettings() const
{
    return m_primaryConfigView && m_primaryConfigView->isVisible();
}


Plasma::Containment *ViewSettingsFactory::lastContainment()
{
    return m_lastContainment;
}

ViewPart::PrimaryConfigView *ViewSettingsFactory::primaryConfigView()
{
    return m_primaryConfigView;
}

void ViewSettingsFactory::warmupPrimaryConfigView(Latte::View *view)
{
    if (m_primaryConfigView || !view || !view->containment()) {
        return;
    }

    //! Builds the settings/canvas chrome ensemble WITHOUT showing it, so the
    //! user's first Edit Dock pays the warm path (~0.5s) instead of the cold
    //! QML instantiation of the whole chrome (~7s measured on the main
    //! thread: thousands of controls plus the Kirigami theme cascade).
    //! Deliberately NO setUserConfiguring(true) here, unlike the real path
    //! below: userConfiguring drives the containment's edit visuals
    //! (containment main.qml binds editMode to it), so setting it would
    //! flash the dock into edit mode for the whole warmup. The chrome is
    //! constructed in the not-configuring state exactly like a warm REOPEN
    //! ends in, and showConfigWindow() establishes the real state later.
    m_primaryConfigView = new ViewPart::PrimaryConfigView(view, false);
}

ViewPart::PrimaryConfigView *ViewSettingsFactory::primaryConfigView(Latte::View *view)
{
    if (!m_primaryConfigView) {
        //!set user configuring early enough in order to give config windows time to be created properly
        view->containment()->setUserConfiguring(true);

        m_primaryConfigView = new ViewPart::PrimaryConfigView(view);
    } else {
        auto previousView = m_primaryConfigView->parentView();

        if (previousView) {
            previousView->releaseConfigView();
        }

        m_primaryConfigView->setParentView(view);
    }

    if (view) {
        m_lastContainment = view->containment();
    }

    return m_primaryConfigView;
}

ViewPart::WidgetExplorerView *ViewSettingsFactory::widgetExplorerView(Latte::View *view)
{
    //! it is deleted on hiding
    auto widgetExplorerView = new ViewPart::WidgetExplorerView(view);
    return widgetExplorerView;
}


}
