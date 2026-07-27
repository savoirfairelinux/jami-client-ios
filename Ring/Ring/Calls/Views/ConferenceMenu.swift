/*
 * Copyright (C) 2019-2026 Savoir-faire Linux Inc.
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

enum ConferenceMenuItem: Hashable {
    case endCall
    case minimize
    case maximize
    case setModerator
    case muteAudio
    case lowerHand

    var title: String {
        switch self {
        case .endCall: return L10n.Accessibility.Conference.endCall
        case .minimize: return L10n.Calls.minimize
        case .maximize: return L10n.Calls.maximize
        case .setModerator: return L10n.Calls.setModerator
        case .muteAudio: return L10n.Calls.muteAudio
        case .lowerHand: return L10n.Calls.lowerHand
        }
    }
}

enum ConferenceRole {
    case host
    case moderator
    case regular
}

struct ConferenceMenuBuilder {

    func menuForLocalTile(layout: ConferenceLayoutMode, isActive: Bool?,
                          isHandRaised: Bool,
                          isModeratorMuted: Bool) -> [ConferenceMenuItem] {
        var menu = [ConferenceMenuItem]()
        guard let isActive = isActive else { return menu }
        if isHandRaised {
            menu.append(.lowerHand)
        }
        switch layout {
        case .grid:
            menu.append(.maximize)
        case .oneWithSmall:
            menu.append(.maximize)
            if isActive {
                menu.append(.minimize)
            }
        case .one:
            menu.append(isActive ? .minimize : .maximize)
        }
        if isModeratorMuted {
            menu.append(.muteAudio)
        }
        return menu
    }

    func menuForParticipant(isHost: Bool, layout: ConferenceLayoutMode, isActive: Bool,
                            role: ConferenceRole, isHandRaised: Bool) -> [ConferenceMenuItem] {
        var menu = [ConferenceMenuItem]()
        if isHandRaised {
            menu.append(.lowerHand)
        }
        switch layout {
        case .grid:
            menu.append(.maximize)
        case .oneWithSmall:
            menu.append(.maximize)
            if isActive {
                menu.append(.minimize)
            }
        case .one:
            menu.append(isActive ? .minimize : .maximize)
        }
        switch role {
        case .host:
            menu.append(.muteAudio)
            menu.append(.setModerator)
            menu.append(.endCall)
        case .moderator:
            menu.append(.muteAudio)
            if !isHost {
                menu.append(.endCall)
            }
        case .regular:
            break
        }
        return menu
    }
}
