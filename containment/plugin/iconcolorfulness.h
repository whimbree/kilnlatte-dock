/*
    SPDX-License-Identifier: GPL-2.0-or-later
*/

#ifndef ICONCOLORFULNESS_H
#define ICONCOLORFULNESS_H

#include <QObject>
#include <QPointer>
#include <QQuickItem>

namespace Latte {
namespace Containment {

//! Measures whether an applet's rendered content is multicolored so the
//! colorizer can exempt it (deliberate Qt5 deviation, explicitly requested:
//! flattening a full-color icon to the scheme text color produces a
//! featureless blob, while monochrome line-art is what the colorizer is
//! for). Pixel truth via QQuickItem::grabToImage, not icon-name heuristics:
//! applets may paint arbitrary compact representations that never touch the
//! icon theme. Lives in C++ because QML Canvas cannot load the itemgrabber:
//! image provider, so the analysis is impossible QML-side.
class IconColorfulness : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QQuickItem *target READ target WRITE setTarget NOTIFY targetChanged)
    Q_PROPERTY(bool known READ known NOTIFY resultChanged)
    Q_PROPERTY(bool colorful READ colorful NOTIFY resultChanged)

public:
    explicit IconColorfulness(QObject *parent = nullptr);

    QQuickItem *target() const;
    void setTarget(QQuickItem *target);

    bool known() const;
    bool colorful() const;

    Q_INVOKABLE void measure();

Q_SIGNALS:
    void targetChanged();
    void resultChanged();

private:
    QPointer<QQuickItem> m_target;
    bool m_known{false};
    bool m_colorful{false};
    bool m_grabInFlight{false};
};

}
}

#endif
