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

destination="${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"
source_framework="${BUILT_PRODUCTS_DIR}/DebugTools.framework"
target_framework="${destination}/DebugTools.framework"

if [ ! -d "${source_framework}" ]; then
    echo "error: DebugTools.framework was not built at ${source_framework}"
    exit 1
fi

mkdir -p "${destination}"
rm -rf "${target_framework}"
/usr/bin/ditto "${source_framework}" "${target_framework}"

if [ "${CODE_SIGNING_ALLOWED:-YES}" != "NO" ]; then
    if [ -z "${EXPANDED_CODE_SIGN_IDENTITY:-}" ]; then
        echo "error: CODE_SIGNING_ALLOWED is enabled but EXPANDED_CODE_SIGN_IDENTITY is empty"
        exit 1
    fi

    /usr/bin/codesign --force --sign "${EXPANDED_CODE_SIGN_IDENTITY}" \
        --preserve-metadata=identifier,entitlements \
        "${target_framework}"
fi
