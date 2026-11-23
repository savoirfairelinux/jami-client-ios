/*
 * Copyright (C) 2026-2026 Savoir-faire Linux Inc.
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

import UIKit

extension AudioOutput {
    var displayName: String {
        switch self {
        case .iPhone: return UIDevice.current.localizedModel
        case .speaker: return L10n.Calls.speaker
        case .wired: return L10n.Calls.headphones
        case let .bluetooth(_, name): return name
        }
    }

    var systemImage: String {
        switch self {
        case .iPhone: return "iphone"
        case .speaker: return "speaker.wave.2.fill"
        case .wired: return "headphones"
        case let .bluetooth(_, name):
            return name.localizedCaseInsensitiveContains("AirPods") ? "airpods" : "headphones"
        }
    }

    /// The call bar shows where the sound comes out: a speaker without
    /// waves reads as the earpiece next to the other round buttons.
    var buttonSystemImage: String {
        self == .iPhone ? "speaker.fill" : systemImage
    }
}
