/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
 *
 *  Author: Silbino Gonçalves Matado <silbino.gmatado@savoirfairelinux.com>
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

enum CallState: String {
    case incoming = "INCOMING"
    case connecting = "CONNECTING"
    case ringing = "RINGING"
    case current = "CURRENT"
    case hungup = "HUNGUP"
    case busy = "BUSY"
    case failure = "FAILURE"
    case hold = "HOLD"
    case unhold = "UNHOLD"
    case inactive = "INACTIVE"
    case over = "OVER"
    case unknown = "UNKNOWN"
}

enum CallType: Int {
    case incoming = 0
    case outgoing
    case missed
}

enum CallDetailKey: String {
    case callTypeKey = "CALL_TYPE"
    case peerNumberKey = "PEER_NUMBER"
    case registeredNameKey = "REGISTERED_NAME"
    case displayNameKey = "DISPLAY_NAME"
    case timeStampStartKey = "TIMESTAMP_START"
    case accountIdKey = "ACCOUNTID"
    case peerHoldingKey = "PEER_HOLDING"
    case audioMutedKey = "AUDIO_MUTED"
    case videoMutedKey = "VIDEO_MUTED"
    case videoSourceKey = "VIDEO_SOURCE"
    case audioOnlyKey = "AUDIO_ONLY"
    case confID = "CONF_ID"
}

public class CallModel {

    var callId: String = ""
    var participantsCallId: Set<String> = Set<String>()
    var callUUID: UUID = UUID()
    var dateReceived: Date?
    var participantUri: String = ""
    var displayName: String = ""
    var registeredName: String = ""
    var accountId: String = ""
    var audioMuted: Bool = false
    var videoMuted: Bool = false
    var peerHolding: Bool = false
    var speakerActive: Bool = false
    var isAudioOnly: Bool = false

    var stateValue = CallState.unknown.rawValue
    var callTypeValue = CallType.missed.rawValue

    var state: CallState {
        get {
            if let state = CallState(rawValue: stateValue) {
                return state
            }
            return CallState.unknown
        }
        set {
            stateValue = newValue.rawValue
        }
    }

    var callType: CallType {
        get {
            if let type = CallType(rawValue: callTypeValue) {
                return type
            }
            return CallType.missed
        }
        set {
            callTypeValue = newValue.rawValue
        }
    }

    init() {
    }

    init(withCallId callId: String, callDetails dictionary: [String: String]) {
        self.callId = callId

        if let fromRingId = dictionary[CallDetailKey.peerNumberKey.rawValue] {
            self.participantUri = fromRingId
        }

        if let accountId = dictionary[CallDetailKey.accountIdKey.rawValue] {
            self.accountId = accountId
        }

        if let callType = dictionary[CallDetailKey.callTypeKey.rawValue] {
            if let callTypeInt = Int(callType) {
                self.callType = CallType(rawValue: callTypeInt) ?? .missed
            } else {
                self.callType = .missed
            }
        }

        self.update(withDictionary: dictionary)
        self.participantsCallId.insert(callId)
    }

    func update(withDictionary dictionary: [String: String]) {

        if self.state == .current && self.dateReceived == nil {
            self.dateReceived = Date()
        }

        if let displayName = dictionary[CallDetailKey.displayNameKey.rawValue], !displayName.isEmpty {
            self.displayName = displayName
        }

        if let registeredName = dictionary[CallDetailKey.registeredNameKey.rawValue], !registeredName.isEmpty {
            self.registeredName = registeredName
        }

        if let videoMuted = dictionary[CallDetailKey.videoMutedKey.rawValue]?.toBool() {
            self.videoMuted = videoMuted
        }

        if let audioMuted = dictionary[CallDetailKey.audioMutedKey.rawValue]?.toBool() {
            self.audioMuted = audioMuted
        }

        if let participantRingId = dictionary[CallDetailKey.peerNumberKey.rawValue] {
            self.participantUri = participantRingId
        }

        if let accountId = dictionary[CallDetailKey.accountIdKey.rawValue] {
            self.accountId = accountId
        }

        if let peerHolding = dictionary[CallDetailKey.peerHoldingKey.rawValue]?.toBool() {
            self.peerHolding = peerHolding
        }

        if let isAudioOnly = dictionary[CallDetailKey.audioOnlyKey.rawValue]?.toBool() {
            self.isAudioOnly = isAudioOnly
        }
//
//        if let confID = dictionary[CallDetailKey.confID.rawValue] {
//            self.conferenceId = confID
//        }
    }
}
