/*
    SPDX-FileCopyrightText: 2026 Bree Spektor
    SPDX-FileCopyrightText: 2026 Latte Dock contributors
    SPDX-License-Identifier: GPL-2.0-or-later
*/

#ifndef LINKEDCONFIGURATIONPOLICY_H
#define LINKEDCONFIGURATIONPOLICY_H

// Qt
#include <QLatin1StringView>
#include <QString>

// C++
#include <string_view>

namespace Latte::Data::LinkedConfigurationPolicy {

//! ConfigOverlay writes this value from a view-local resize handle. Its axis
//! and useful range depend on that view's orientation and output geometry, so
//! copying it through a linked relationship contaminates unrelated sizing.
inline constexpr std::string_view AppletLengthKey{"length"};

[[nodiscard]] constexpr bool isPerViewAppletConfigurationKey(
    const std::string_view key) noexcept
{
    return key == AppletLengthKey;
}

[[nodiscard]] inline bool isPerViewAppletConfigurationKey(const QString &key) noexcept
{
    return key == QLatin1StringView(
        AppletLengthKey.data(), static_cast<qsizetype>(AppletLengthKey.size()));
}

[[nodiscard]] inline QString appletLengthKey()
{
    return QString::fromLatin1(
        AppletLengthKey.data(), static_cast<qsizetype>(AppletLengthKey.size()));
}

}

#endif
