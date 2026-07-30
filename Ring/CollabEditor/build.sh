#!/bin/sh
#
# Builds the collaborative editor into the application bundle, or runs its
# tests. Both are driven from Xcode build phases; the bundle is a build
# product, so only its sources are committed.
#
# Usage: build.sh <resources directory>
#        build.sh --test
#
# Copyright (C) 2004-2026 Savoir-faire Linux Inc.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

set -e

export PATH="$PATH:/opt/homebrew/bin:/usr/local/bin"

cd "$(dirname "$0")"

if ! command -v npm > /dev/null; then
    echo "error: npm is required to build the collaborative editor." >&2
    echo "note: install Node.js, e.g. brew install node" >&2
    exit 1
fi

# npm ci starts by erasing node_modules, so a build that changes nothing pays
# for the whole install. Reinstall only once the lock file has moved.
if [ ! -e node_modules/.package-lock.json ] ||
   [ package-lock.json -nt node_modules/.package-lock.json ]; then
    npm ci
fi

if [ "$1" = "--test" ]; then
    npm test
elif [ -n "$1" ]; then
    node esbuild.mjs --outdir "$1"
else
    node esbuild.mjs
fi
