/*
*  Copyright (C) 2020 Savoir-faire Linux Inc.
*
*  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
*
*  This program is free software; you can redistribute it and/or modify
*  it under the terms of the GNU General Public License as published by
*  the Free Software Foundation; either version 3 of the License, or
*  (at your option) any later version.
*
*  This program is distributed in the hope that it will be useful,
*  but WITHOUT ANY WARRANTY; without even the implied warranty of
*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*  GNU General Public License for more details.
*
*  You should have received a copy of the GNU General Public License
*  along with this program; if not, write to the Free Software
*  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA.
*/
enum RoleInCall {
    case moderator
    case host
    case regular
}
class ConferenceMenuItemsManager {
    func getMenuItemsForLocalCall(conference: CallModel?, active: Bool?) -> [MenuItem] {
        var menu = [MenuItem]()
        menu.append(.name)
        guard let conference = conference else {
            return menu
        }
        guard let active = active else {
            return menu
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

    func getMenuItemsFor(call: CallModel?, isHost: Bool, conference: CallModel?, active: Bool?, role: RoleInCall) -> [MenuItem] {
        var menu = [MenuItem]()
        menu.append(.name)
        guard let conference = conference,
            let call = call else {
            return menu
        }
        if call.state != CallState.current {
            menu.append(.hangup)
            return menu
        }
        guard let active = active else {
            return menu
        }
        switch conference.layout {
        case .grid:
            menu.append(.maximize)
            switch role {
            case .host:
                menu.append(.muteAudio)
                menu.append(.setModerator)
                menu.append(.hangup)
            case .moderator:
                menu.append(.muteAudio)
                if !isHost {
                    menu.append(.hangup)
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
                menu.append(.hangup)
            case .moderator:
                menu.append(.muteAudio)
                if !isHost {
                    menu.append(.hangup)
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
                menu.append(.hangup)
            case .moderator:
                menu.append(.muteAudio)
                if !isHost {
                    menu.append(.hangup)
                }
            case .regular:
                break
            }
        }
        return menu
    }
}
