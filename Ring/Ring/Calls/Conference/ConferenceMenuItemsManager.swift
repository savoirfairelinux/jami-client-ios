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

class ConferenceMenuItemsManager {
    func getMenuItemsForMasterCall(conference: CallModel?, active: Bool?) -> MenuMode {
        guard let conference = conference else {
            return MenuMode.onlyName
        }
        guard let active = active else {
            return MenuMode.onlyName
        }
        switch conference.layout {
        case .grid:
            return MenuMode.withoutHangUPAndMinimize
        case .oneWithSmal:
            return active ? MenuMode.withoutHangUp : MenuMode.withoutHangUPAndMinimize
        case .one:
            return active ? MenuMode.withoutHangUPAndMaximize : MenuMode.withoutHangUPAndMinimize
        }
    }

    func getMenuItemsFor(call: CallModel?, conference: CallModel?, active: Bool?) -> MenuMode {
        guard let conference = conference,
            let call = call else {
                return MenuMode.onlyName
        }
        if call.state != CallState.current {
            return MenuMode.withoutMaximizeAndMinimize
        }
        guard let active = active else { return MenuMode.onlyName }
        switch conference.layout {
        case .grid:
            return MenuMode.withoutMinimize
        case .oneWithSmal:
            return active ? MenuMode.all : MenuMode.withoutMinimize
        case .one:
            return active ? MenuMode.withoutMaximize : MenuMode.withoutMinimize
        }
    }
}
