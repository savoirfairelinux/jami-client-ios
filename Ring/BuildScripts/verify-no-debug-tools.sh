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

if [ "${CONFIGURATION}" = "Debug Testing" ]; then
    exit 0
fi

frameworks_dir="${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"
binary="${TARGET_BUILD_DIR}/${EXECUTABLE_PATH}"
project_file="${PROJECT_DIR}/${PROJECT_NAME}.xcodeproj/project.pbxproj"
failed=0

if [ -e "${frameworks_dir}/DebugTools.framework" ]; then
    echo "error: DebugTools.framework leaked into ${CONFIGURATION} bundle"
    failed=1
fi

if [ -e "${frameworks_dir}/libopentelemetry.framework" ]; then
    echo "error: libopentelemetry.framework leaked into ${CONFIGURATION} bundle"
    failed=1
fi

if [ -f "${binary}" ] && /usr/bin/otool -L "${binary}" | /usr/bin/grep -E "DebugTools|libopentelemetry" >/dev/null; then
    echo "error: ${CONFIGURATION} binary links a debug-only framework"
    /usr/bin/otool -L "${binary}" | /usr/bin/grep -E "DebugTools|libopentelemetry"
    failed=1
fi

if printf '%s\n%s\n' "${OTHER_LDFLAGS:-}" "${FRAMEWORK_SEARCH_PATHS:-}" | /usr/bin/grep -E "DebugTools|libopentelemetry" >/dev/null; then
    echo "error: ${CONFIGURATION} build settings reference debug-only frameworks"
    printf '%s\n%s\n' "${OTHER_LDFLAGS:-}" "${FRAMEWORK_SEARCH_PATHS:-}" | /usr/bin/grep -E "DebugTools|libopentelemetry"
    failed=1
fi

if [ -f "${project_file}" ] && /usr/bin/grep -E "(DebugTools\.framework|libopentelemetry\.xcframework) in (Frameworks|Embed Frameworks)" "${project_file}" >/dev/null; then
    echo "error: debug-only frameworks are wired into an unconditional Xcode build phase"
    /usr/bin/grep -E "(DebugTools\.framework|libopentelemetry\.xcframework) in (Frameworks|Embed Frameworks)" "${project_file}"
    failed=1
fi

exit "${failed}"
