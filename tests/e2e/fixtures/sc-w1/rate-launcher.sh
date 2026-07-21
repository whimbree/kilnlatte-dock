#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Bree Spektor
# SPDX-FileCopyrightText: 2026 Latte Dock contributors
# SPDX-License-Identifier: GPL-2.0-or-later
set -eu

: "${SC_W1_RATE_LAUNCH_LOG:?}"
: "${SC_W1_RATE_PID_LOG:?}"

printf 'launch\n' >> "$SC_W1_RATE_LAUNCH_LOG"
printf '%s\n' "$$" >> "$SC_W1_RATE_PID_LOG"
exec sleep 60
