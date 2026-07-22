/*
    SPDX-FileCopyrightText: 2026 Bree Spektor
    SPDX-FileCopyrightText: 2026 Latte Dock contributors

    SPDX-License-Identifier: GPL-2.0-or-later
*/

#pragma once

namespace Latte {
namespace ViewActionPolicy {

enum class Action
{
    Duplicate,
    ExportTemplate,
    MoveToLayout,
    Remove,
};

enum class Role
{
    Original,
    Clone,
};

//! Screen-group clones are implementation members of an original dock. Moving,
//! exporting, or removing one member would escape that relationship, so those
//! actions stay owned by the original. Duplicate is intentionally different:
//! it breaks the relationship and creates one independent snapshot, whether
//! the visible source is the original or one of its linked replicas.
constexpr bool permits(const Role role, const Action action)
{
    switch (action) {
    case Action::Duplicate:
        return true;
    case Action::ExportTemplate:
    case Action::MoveToLayout:
    case Action::Remove:
        return role == Role::Original;
    }

    return false;
}

} // namespace ViewActionPolicy
} // namespace Latte
