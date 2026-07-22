/*
    SPDX-FileCopyrightText: 2026 Bree Spektor
    SPDX-FileCopyrightText: 2026 Latte Dock contributors

    SPDX-License-Identifier: GPL-2.0-or-later
*/

#pragma once

#include <cstdint>

#include <QtGlobal>

namespace Latte {
namespace ViewPart {

//! Process-local generation state for deferred config-window retargets. A
//! request token can be consumed exactly once and only while it remains the
//! newest request. The QTimer adapter also stops the old timer; this generation
//! check rejects an already-queued timeout that cancellation cannot retract.
class RetargetRequestState
{
public:
    using Token = std::uint64_t;
    using TargetKey = std::uintptr_t;

    [[nodiscard]] Token beginRequest(const TargetKey target)
    {
        Q_ASSERT(target != 0);
        m_target = target;
        return ++m_generation;
    }

    void cancelRequest()
    {
        m_target = 0;
        ++m_generation;
    }

    [[nodiscard]] bool isTargetPending(const TargetKey target) const
    {
        return target != 0 && m_target == target;
    }

    [[nodiscard]] bool consumeIfCurrent(const Token token)
    {
        if (token != m_generation) {
            return false;
        }

        m_target = 0;
        ++m_generation;
        return true;
    }

private:
    Token m_generation{0};
    TargetKey m_target{0};
};

} // namespace ViewPart
} // namespace Latte
