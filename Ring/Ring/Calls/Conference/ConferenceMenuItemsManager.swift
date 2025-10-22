/*
 * Copyright (C) 2020-2025 Savoir-faire Linux Inc.
 *
 * Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
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

enum RoleInCall {
    case moderator
    case host
    case regular
}
class ConferenceMenuItemsManager {
    func getMenuItemsForLocalCall(conference: CallModel?, active: Bool?, isHandRised: Bool) -> [MenuItem] {
        var menu = [MenuItem]()
        guard let conference = conference else {
            return menu
        }
        guard let active = active else {
            return menu
        }
        if isHandRised {
            menu.append(.lowerHand)
        }
        switch conference.layout {
        case .grid:
            menu.append(.maximize)
        case .oneWithSmal:
            menu.append(.maximize)
            if active {
                menu.append(.minimize)
            }
        case .one:
            if active {
                menu.append(.minimize)
            } else {
                menu.append(.maximize)
            }
        }
        menu.append(.muteAudio)
        return menu
    }

    func getMenuItemsForLocalCall(layout: CallLayout, active: Bool?, isHandRised: Bool) -> [MenuItem] {
        var menu = [MenuItem]()
        guard let active = active else {
            return menu
        }
        if isHandRised {
            menu.append(.lowerHand)
        }
        switch layout {
        case .grid:
            menu.append(.maximize)
        case .oneWithSmal:
            menu.append(.maximize)
            if active {
                menu.append(.minimize)
            }
        case .one:
            if active {
                menu.append(.minimize)
            } else {
                menu.append(.maximize)
            }
        }
        menu.append(.muteAudio)
        return menu
    }

    // swiftlint:disable cyclomatic_complexity
    func getMenuItemsFor(call: CallModel?, isHost: Bool, conference: CallModel?, active: Bool?, role: RoleInCall, isHandRised: Bool) -> [MenuItem] {
        var menu = [MenuItem]()
        guard let conference = conference,
              let call = call else {
            return menu
        }
        if call.state != CallState.current {
            menu.append(.endCall)
            return menu
        }
        guard let active = active else {
            return menu
        }
        if isHandRised {
            menu.append(.lowerHand)
        }
        switch conference.layout {
        case .grid:
            menu.append(.maximize)
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
        case .oneWithSmal:
            if active {
                menu.append(.maximize)
                menu.append(.minimize)
            } else {
                menu.append(.maximize)
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
        case .one:
            if active {
                menu.append(.minimize)
            } else {
                menu.append(.maximize)
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
        }
        return menu
    }

    // swiftlint:disable cyclomatic_complexity
    func getMenuItemsFor(isHost: Bool, layout: CallLayout, active: Bool, role: RoleInCall, isHandRised: Bool) -> [MenuItem] {
        var menu = [MenuItem]()
        if isHandRised {
            menu.append(.lowerHand)
        }
        switch layout {
        case .grid:
            menu.append(.maximize)
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
        case .oneWithSmal:
            if active {
                menu.append(.maximize)
                menu.append(.minimize)
            } else {
                menu.append(.maximize)
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
        case .one:
            if active {
                menu.append(.minimize)
            } else {
                menu.append(.maximize)
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
        }
        return menu
    }
}
