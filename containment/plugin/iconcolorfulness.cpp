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
//! analysis geometry and thresholds. The grab is taken at 48x48 (close to
//! the rendered size, faithful), then CPU area-averaged down to 12x12
//! cells BEFORE judging: subpixel-antialiased text (the digital clock's
//! NativeRendering labels) fringes every glyph stroke cyan on one edge
//! and orange on the other - individually saturated pixels engineered to
//! sum to the stroke's neutral color - and judged per-pixel it measured
//! 49-84% "saturated" for pure white text (grab dumps in hand,
//! 2026-07-15), permanently exempting the clock from colorizing. The
//! complementary pair always sits within one stroke width, so averaging
//! over cells WIDER than a stroke cancels it locally, while an icon's
//! solid color regions fill whole cells and survive. The averaging must
//! be the CPU QImage::scaled smooth path (a true full-area box filter);
//! grabbing small instead leaves the downscale to GPU bilinear filtering,
//! which taps too few texels to guarantee both fringes land in the blend
//! (measured: a 24x24 grab still judged 67% of the clock saturated).
//! A cell is judged colorful above 0.30 saturation; content is
//! "multicolored" when more than 15% of its opaque cells are colorful.
constexpr int SAMPLESIZE = 48;
constexpr int JUDGESIZE = 12;
constexpr qreal SATURATIONTHRESHOLD = 0.30;
constexpr qreal COLORFULFRACTION = 0.15;
//! fewer opaque cells than this means the content has not rendered yet
//! (icons load late); the caller retries instead of trusting a blank grab
constexpr int MINOPAQUEPIXELS = 8;
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

        const QImage grabbed = grab->image();
        if (grabbed.isNull()) {
            return;
        }

        //! the subpixel-fringe canceling area average, see the constants
        const QImage img = grabbed.scaled(QSize(JUDGESIZE, JUDGESIZE), Qt::IgnoreAspectRatio, Qt::SmoothTransformation);

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
