/*
 *  Copyright (C) 2019 Savoir-faire Linux Inc.
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

import Foundation
import Intents
extension NSUserActivity {
    var startCallHandle: (hash: String, isVideo: Bool)? {
        guard let interaction = interaction else { return nil }
        let startVideoCallIntent = interaction.intent as? INStartVideoCallIntent
        let startAudioCallIntent = interaction.intent as? INStartAudioCallIntent
        if startVideoCallIntent == nil && startAudioCallIntent == nil {
            return nil
        }
        let isVideo = startVideoCallIntent != nil ? true : false
        if isVideo {
            guard
                let intent = startVideoCallIntent,
                let contact = intent.contacts?.first,
                let handle = contact.personHandle,
                let value = handle.value else {
                    return nil
            }
            return(value, true)
        }
        guard
            let intent = startAudioCallIntent,
            let contact = intent.contacts?.first,
            let handle = contact.personHandle,
            let value = handle.value else {
                return nil
        }
        return(value, false)
    }
}
