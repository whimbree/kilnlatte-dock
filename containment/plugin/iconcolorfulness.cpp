/*
    SPDX-License-Identifier: GPL-2.0-or-later
*/

#include "iconcolorfulness.h"

#include <QColor>
#include <QImage>
#include <QQuickItemGrabResult>

namespace Latte {
namespace Containment {

namespace {
//! analysis geometry and thresholds: a 24x24 downscale is plenty to judge
//! color content; saturation above 0.30 marks a pixel as carrying real
//! color; content is "multicolored" when more than 15% of its opaque
//! pixels carry color
constexpr int SAMPLESIZE = 24;
constexpr qreal SATURATIONTHRESHOLD = 0.30;
constexpr qreal COLORFULFRACTION = 0.15;
//! fewer opaque pixels than this means the content has not rendered yet
//! (icons load late); the caller retries instead of trusting a blank grab
constexpr int MINOPAQUEPIXELS = 16;
}

IconColorfulness::IconColorfulness(QObject *parent)
    : QObject(parent)
{
}

QQuickItem *IconColorfulness::target() const
{
    return m_target;
}

void IconColorfulness::setTarget(QQuickItem *target)
{
    if (m_target == target) {
        return;
    }

    m_target = target;
    m_known = false;
    m_colorful = false;
    Q_EMIT targetChanged();
    Q_EMIT resultChanged();

    measure();
}

bool IconColorfulness::known() const
{
    return m_known;
}

bool IconColorfulness::colorful() const
{
    return m_colorful;
}

void IconColorfulness::measure()
{
    if (!m_target || m_grabInFlight || m_target->width() < 1 || m_target->height() < 1) {
        return;
    }

    auto grab = m_target->grabToImage(QSize(SAMPLESIZE, SAMPLESIZE));
    if (!grab) {
        return;
    }

    m_grabInFlight = true;

    //! the shared pointer captured by value keeps the grab result alive
    //! until ready fires (letting it go collects the result and the image)
    connect(grab.data(), &QQuickItemGrabResult::ready, this, [this, grab]() {
        m_grabInFlight = false;

        const QImage img = grab->image();
        if (img.isNull()) {
            return;
        }

        int opaque = 0;
        int saturated = 0;

        for (int y = 0; y < img.height(); ++y) {
            for (int x = 0; x < img.width(); ++x) {
                const QColor c = img.pixelColor(x, y);
                if (c.alphaF() < 0.5) {
                    continue;
                }
                opaque++;
                if (c.hsvSaturationF() > SATURATIONTHRESHOLD) {
                    saturated++;
                }
            }
        }

        if (opaque < MINOPAQUEPIXELS) {
            //! not rendered yet; stay unknown so the QML retry can fire again
            return;
        }

        const bool colorful = (static_cast<qreal>(saturated) / opaque) > COLORFULFRACTION;

        if (!m_known || colorful != m_colorful) {
            m_known = true;
            m_colorful = colorful;
            Q_EMIT resultChanged();
        } else {
            m_known = true;
        }
    });
}

}
}
