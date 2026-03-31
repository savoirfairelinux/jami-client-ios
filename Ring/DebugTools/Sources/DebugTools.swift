/*
 * Copyright (C) 2026 - 2026 Savoir-faire Linux Inc.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA.
 */

import Foundation

// DEBUG_TOOLS_ENABLED is set in the "Debug Testing" build configuration,
// which inherits from Debug, so DEBUG must always be defined
// when DEBUG_TOOLS_ENABLED is.
#if DEBUG_TOOLS_ENABLED && !DEBUG
#error("DEBUG_TOOLS_ENABLED must never be enabled in a non-DEBUG build configuration. Did you select Jami-TestingTools for an Archive/Release build?")
#endif

#if DEBUG_TOOLS_ENABLED

/// Top-level namespace for the DebugTools framework.
public enum DebugTools {
    /// Framework version. Bump when making breaking API changes to any tool.
    public static let version = "1.0.0"
}

#endif
