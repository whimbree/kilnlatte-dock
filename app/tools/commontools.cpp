/*
    SPDX-FileCopyrightText: 2018 Michail Vourlakos <mvourlakos@gmail.com>
    SPDX-FileCopyrightText: 2026 Bree Spektor
    SPDX-FileCopyrightText: 2026 Latte Dock contributors
    SPDX-License-Identifier: GPL-2.0-or-later

*/

#include "commontools.h"

// Qt
#include <QDebug>
#include <QDir>
#include <QFileInfo>
#include <QQuickItem>
#include <QQuickWindow>
#include <QStandardPaths>
#include <QStringList>


namespace Latte {

QString rectToString(const QRect &rect)
{
    QString result;
    result += QString(QString::number(rect.x()) + ","  + QString::number(rect.y()));
    result += " ";
    result += QString(QString::number(rect.width()) + "x" + QString::number(rect.height()));

    return result;
}

QRect stringToRect(const QString &str)
{
    //! boundary refusal, not a guard over a bug: the string arrives from
    //! persisted screen data (Data::Screen::init), which lives in
    //! user-editable config - a hand-corrupted entry must be refused loudly,
    //! never index out of range or smuggle zeros in as geometry
    const QStringList parts = str.split(" ");
    const QStringList pos = parts.count() == 2 ? parts[0].split(",") : QStringList();
    const QStringList size = parts.count() == 2 ? parts[1].split("x") : QStringList();

    if (pos.count() != 2 || size.count() != 2) {
        qWarning() << "stringToRect: malformed rect string, refusing:" << str;
        return QRect();
    }

    bool xOk{false}, yOk{false}, wOk{false}, hOk{false};
    const QRect result(pos[0].toInt(&xOk), pos[1].toInt(&yOk), size[0].toInt(&wOk), size[1].toInt(&hOk));

    if (!xOk || !yOk || !wOk || !hOk) {
        qWarning() << "stringToRect: non-numeric rect component, refusing:" << str;
        return QRect();
    }

    return result;
}

QString standardPath(QString subPath, bool localfirst)
{
    QStringList paths = QStandardPaths::standardLocations(QStandardPaths::GenericDataLocation);

    QString separator = subPath.startsWith("/") ? "" : "/";

    if (localfirst) {
        for (const auto &pt : paths) {
            QString ptF = pt + separator +subPath;
            if (QFileInfo(ptF).exists()) {
                return ptF;
            }
        }
    } else {
        for (int i=paths.count()-1; i>=0; i--) {
            QString ptF = paths[i] + separator +subPath;
            if (QFileInfo(ptF).exists()) {
                return ptF;
            }
        }
    }

    //! in any case that above fails
    if (QFileInfo("/usr/share" + separator + subPath).exists()) {
        return "/usr/share" + separator + subPath;
    }

    return "";
}

QString configPath()
{
    QStringList configPaths = QStandardPaths::standardLocations(QStandardPaths::ConfigLocation);

    if (configPaths.count() == 0) {
        return QDir::homePath() + "/.config";
    }

    return configPaths[0];
}


bool compositingActive()
{
    //! the wayland compositor is the display server - compositing is
    //! unconditional on the only platform the dock runs on
    return true;
}

QQuickWindow *visualHostWindowOf(const QWindow *window)
{
    //! QObject::parent() explicitly: QWindow::parent() is the window-parent
    //! overload, null for a QML-declared dialog (see the header note)
    for (QObject *ancestor = window->QObject::parent(); ancestor; ancestor = ancestor->parent()) {
        auto *item = qobject_cast<QQuickItem *>(ancestor);

        if (!item || !item->window() || item->window() == window) {
            continue;
        }

        return item->window();
    }

    return nullptr;
}

}
