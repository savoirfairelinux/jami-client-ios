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

class ConferenceParticipant: Hashable {
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
    var isHandRaised: Bool = false
    var device: String = ""
    var sinkId: String = ""
    var voiceActivity: Bool = false
    var recording: Bool = false
    var audioModeratorMuted: Bool = false

    init(info: [String: String], onlyURIAndActive: Bool) {
        uri = info["uri"]
        if let participantActive = info["active"] {
            isActive = participantActive == "true"
        }
        if onlyURIAndActive {
            return
        }
        if let pointX = info["x"] {
            originX = CGFloat((pointX as NSString).doubleValue)
        }
        if let pointY = info["y"] {
            originY = CGFloat((pointY as NSString).doubleValue)
        }
        if let participantWidth = info["w"] {
            width = CGFloat((participantWidth as NSString).doubleValue)
        }
        if let participantHeight = info["h"] {
            height = CGFloat((participantHeight as NSString).doubleValue)
        }
        if let videoMuted = info["videoMuted"] {
            isVideoMuted = videoMuted.boolValue
        }
        if let audioLocalMuted = info["audioLocalMuted"] {
            isAudioLocalyMuted = audioLocalMuted.boolValue
        }
        if let audioModeratorMuted = info["audioModeratorMuted"] {
            isAudioMuted = audioModeratorMuted.boolValue
        }
        if let isModerator = info["isModerator"] {
            self.isModerator = isModerator.boolValue
        }
        if let isHandRaised = info["handRaised"] {
            self.isHandRaised = isHandRaised.boolValue
        }
        if let device = info["device"] {
            self.device = device
        }

        if let sinkId = info["sinkId"] {
            self.sinkId = sinkId
        }

        if let voiceActivity = info["voiceActivity"] {
            self.voiceActivity = voiceActivity.boolValue
        }

        if let recording = info["recording"] {
            self.recording = recording.boolValue
        }

        if let audioModeratorMuted = info["audioModeratorMuted"] {
            self.audioModeratorMuted = audioModeratorMuted.boolValue
        }
    }

    init(sinkId: String, isActive: Bool) {
        self.sinkId = sinkId
        self.isActive = isActive
    }

    func hash(into hasher: inout Hasher) {
        return hasher.combine(uri)
    }

    static func == (lhs: ConferenceParticipant, rhs: ConferenceParticipant) -> Bool {
        return lhs.uri == rhs.uri
    }
}
