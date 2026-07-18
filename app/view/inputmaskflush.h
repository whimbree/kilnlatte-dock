/*
    SPDX-FileCopyrightText: 2026 Latte Dock contributors
    SPDX-FileCopyrightText: 2026 Bree Spektor
    SPDX-License-Identifier: GPL-2.0-or-later
*/

#ifndef INPUTMASKFLUSH_H
#define INPUTMASKFLUSH_H

// Qt
#include <QRect>

namespace Latte {
namespace ViewPart {

//! Qt6's wayland backend couples QWindow::mask() to each frame's submitted
//! buffer damage (Effects::setInputMask records the history: an empty mask
//! froze the whole surface at its last content). The consequence that forced
//! this seam: when a masked dock's visible band SHRINKS - e.g. "maximize panel
//! length in presence of maximized windows" grew it to full width and releases
//! on un-maximize - the just-vacated edge pixels are repainted transparent by
//! the scene graph, but that damage falls outside the new, smaller mask and is
//! dropped. The compositor keeps compositing the stale semi-transparent panel
//! pixels there, a lighter frosted band at the former extent (reproduced live
//! on a real top dock, 2026-07-18). Qt5/X11 shape masks did not clip damage, so
//! this is a platform-forced Qt6 deviation with no upstream precedent.
//!
//! The fix keeps the WINDOW mask at the union of the bands seen since the band
//! last settled, so a shrink never clips the vacated region's clearing damage,
//! and collapses back to the exact band once the band stops changing (a
//! coalescing timer in Effects). These pure helpers own the "what region to
//! hand QWindow::setMask" decision so the invariant is testable without a live
//! compositor. m_inputMask still reports the logical band for readback.
namespace InputMaskFlush {

//! The region to hand QWindow::setMask, given the region currently applied to
//! the window and the new logical band. A clear/degenerate band clears the
//! mask; a first band with no prior applied mask is used as-is; otherwise the
//! union is kept. Growing therefore collapses to the band on its own (a wider
//! band already contains the old applied region, union == band), while a shrink
//! stays wide (union == the old, wider applied region) and must be narrowed
//! later by the settle collapse.
inline QRect windowMaskFor(const QRect &applied, const QRect &band)
{
    if (!band.isValid() || band.isEmpty()) {
        return QRect();
    }

    if (!applied.isValid() || applied.isEmpty()) {
        return band;
    }

    //! Contract: the region handed to setMask never drops coverage of what is
    //! currently applied. A shrink therefore keeps the union so the vacated
    //! edges' clearing damage stays inside the mask (the whole reason this seam
    //! exists); coverage only narrows through the deliberate settle collapse in
    //! Effects, never here. united() satisfies this by construction. A naive
    //! `return band` violates it on a shrink and trips this assert under the
    //! sanitized tests (QT_FORCE_ASSERTS live, stripped in the shipped dock) -
    //! the tripwire that keeps a future "simplification" from reintroducing the
    //! stale frosted band.
    const QRect result = applied.united(band);
    Q_ASSERT(result.contains(applied));
    return result;
}

//! Whether the applied window mask is still wider than the band, so the settle
//! collapse must run once the band stops changing (steady-state hit-testing and
//! libplasma popup anchoring both read the window mask and need the real band).
inline bool needsSettleCollapse(const QRect &applied, const QRect &band)
{
    return band.isValid() && !band.isEmpty() && applied != band;
}

} // namespace InputMaskFlush
} // namespace ViewPart
} // namespace Latte

#endif
