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

class ConferenceParticipant {
    var originX: CGFloat = 0
    var originY: CGFloat = 0
    var width: CGFloat = 0
    var height: CGFloat = 0
    var uri: String?
    var isActive: Bool = false
    var displayName: String = ""
    var isModerator: Bool = false
    var isAudioLocalyMuted: Bool = false
    var isAudioMuted: Bool = false
    var isVideoMuted: Bool = false

    init (info: [String: String], onlyURIAndActive: Bool) {
        self.uri = info["uri"]
        if let participantActive = info["active"] {
            self.isActive = participantActive == "true"
        }
        if onlyURIAndActive {
            return
        }
        if let pointX = info["x"] {
            self.originX = CGFloat((pointX as NSString).doubleValue)
        }
        if let pointY = info["y"] {
            self.originY = CGFloat((pointY as NSString).doubleValue)
        }
        if let participantWidth = info["w"] {
            self.width = CGFloat((participantWidth as NSString).doubleValue)
        }
        if let participantHeight = info["h"] {
            self.height = CGFloat((participantHeight as NSString).doubleValue)
        }
        if let videoMuted = info["videoMuted"] {
            self.isVideoMuted = videoMuted.boolValue
        }
        if let audioLocalMuted = info["audioLocalMuted"] {
            self.isAudioLocalyMuted = audioLocalMuted.boolValue
        }
        if let audioModeratorMuted = info["audioModeratorMuted"] {
            self.isAudioMuted = audioModeratorMuted.boolValue
        }
        if let isModerator = info["isModerator"] {
            self.isModerator = isModerator.boolValue
        }
    }
}
