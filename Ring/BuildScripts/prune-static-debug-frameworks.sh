#!/bin/sh
#
# Copyright (C) 2026 Savoir-faire Linux Inc.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.
#
set -eu

if [ "${CONFIGURATION}" != "Debug Testing" ]; then
    exit 0
fi

frameworks_dir="${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"

# libopentelemetry.xcframework currently contains static framework slices.
# It must be linked for Debug Testing but not embedded in any bundle.
rm -rf "${frameworks_dir}/libopentelemetry.framework"
