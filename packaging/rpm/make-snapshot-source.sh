#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Latte Dock contributors
# SPDX-FileCopyrightText: 2026 Bree Spektor
# SPDX-License-Identifier: GPL-2.0-or-later
set -euo pipefail

if [[ "$#" -ne 1 ]]; then
    echo "Usage: packaging/rpm/make-snapshot-source.sh OUTPUT_DIRECTORY" >&2
    exit 2
fi

repo="$(git rev-parse --show-toplevel)"
output_dir="$1"
[[ -d "$output_dir" ]] || {
    echo "Snapshot output directory does not exist: $output_dir" >&2
    exit 2
}

git -C "$repo" diff --quiet --ignore-submodules -- || {
    echo "Tracked working-tree changes prevent an exact-HEAD source archive" >&2
    exit 2
}
git -C "$repo" diff --cached --quiet --ignore-submodules -- || {
    echo "Staged changes prevent an exact-HEAD source archive" >&2
    exit 2
}

commit="$(git -C "$repo" rev-parse --verify HEAD)"
commit_date="$(git -C "$repo" show -s --format=%cs "$commit")"
snapshot_date="${commit_date//-/}"
version="$(git -C "$repo" show "$commit:packaging/rpm/latte-dock.spec" \
    | awk '$1 == "Version:" { print $2; exit }')"
[[ -n "$version" ]] || {
    echo "Cannot read Version from the tracked RPM spec" >&2
    exit 2
}

archive="$output_dir/latte-dock-$version-$commit.tar.gz"
build_spec="$output_dir/latte-dock.spec"
[[ ! -e "$archive" ]] || {
    echo "Refusing to replace existing snapshot archive: $archive" >&2
    exit 2
}
[[ ! -e "$build_spec" ]] || {
    echo "Refusing to replace existing snapshot spec: $build_spec" >&2
    exit 2
}

git -C "$repo" archive --format=tar --prefix="latte-dock-$version/" "$commit" \
    | gzip -n -9 >"$archive"
git -C "$repo" show "$commit:packaging/rpm/latte-dock.spec" \
    | awk -v commit="$commit" -v snapshot_date="$snapshot_date" '
        NR == 4 {
            print "%global snapshot_commit " commit
            print "%global snapshot_date " snapshot_date
            print ""
        }
        { print }
    ' >"$build_spec"

echo "snapshot_commit=$commit"
echo "snapshot_date=$snapshot_date"
echo "source_archive=$archive"
echo "build_spec=$build_spec"
sha256sum "$archive"
