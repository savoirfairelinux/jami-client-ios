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

    func toString() -> String {
        switch self {
        case .connecting:
            return L10n.Calls.connecting
        case .ringing:
            return L10n.Calls.ringing
        case .over:
            return L10n.Calls.callFinished
        case .unknown:
            return L10n.Global.search
        default:
            return ""
        }
    }

    func isFinished() -> Bool {
        return self == .over || self == .hungup || self == .failure
    }

    func isActive() -> Bool {
        return self == .incoming || self == .connecting || self == .ringing || self == .current || self == .hold || self == .unhold
    }
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
    case videoCodec = "VIDEO_CODEC"
}

enum MediaAttributeKey: String {
    case mediaType = "MEDIA_TYPE"
    case enabled = "ENABLED"
    case muted = "MUTED"
    case source = "SOURCE"
    case sourceType = "SOURCE_TYPE"
    case label = "LABEL"
    case onHold = "ON_HOLD"
}

enum MediaAttributeValue: String {
    case audio = "MEDIA_TYPE_AUDIO"
    case video = "MEDIA_TYPE_VIDEO"
    case srcTypeNone = "NONE"
    case srcTypeCapturedDevice = "CAPTURE_DEVICE"
    case srcTypeDisplay = "DISPLAY"
    case srcTypeFile = "FILE"
}

enum CallLayout: Int32 {
    case grid
    case oneWithSmal
    case one
}

public class CallModel {

    var callId: String = ""
    var participantsCallId: Set<String> = Set<String>() {
        didSet {
            if self.participantsCallId.count <= 1 {
                self.layout = .one
            }
        }
    }
    var callUUID: UUID = UUID()
    var dateReceived: Date?
    var participantUri: String = ""
    var displayName: String = ""
    var registeredName: String = ""
    var accountId: String = ""
    var conversationId: String = ""
    var audioMuted: Bool = false
    var callRecorded: Bool = false
    var videoMuted: Bool = false
    var peerHolding: Bool = false
    var speakerActive: Bool = false
    var isAudioOnly: Bool = false
    var layout: CallLayout = .one
    lazy var paricipantHash = {
        self.participantUri.filterOutHost()
    }
    var mediaList: [[String: String]] = [[String: String]]()

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

    init(withCallId callId: String, callDetails dictionary: [String: String], withMedia mediaList: [[String: String]]) {
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

        self.update(withDictionary: dictionary, withMedia: mediaList)
        self.participantsCallId.insert(callId)
    }

    func checkDeviceMediaMuted(media: [String: String]) -> Bool {
        if media[MediaAttributeKey.sourceType.rawValue] != MediaAttributeValue.srcTypeFile.rawValue && media[MediaAttributeKey.sourceType.rawValue] != MediaAttributeValue.srcTypeDisplay.rawValue {
            if media[MediaAttributeKey.muted.rawValue] == "true" || media[MediaAttributeKey.enabled.rawValue] == "false" {
                return true
            }
        }
        return false
    }

    func update(withDictionary dictionary: [String: String], withMedia mediaList: [[String: String]]) {

        if self.state == .current && self.dateReceived == nil {
            self.dateReceived = Date()
        }

        if !mediaList.isEmpty {
            self.mediaList = mediaList
        }

        if let displayName = dictionary[CallDetailKey.displayNameKey.rawValue], !displayName.isEmpty {
            self.displayName = displayName
        }

        if let registeredName = dictionary[CallDetailKey.registeredNameKey.rawValue], !registeredName.isEmpty {
            self.registeredName = registeredName
        }

        self.isAudioOnly = true
        self.videoMuted = true
        for (item) in self.mediaList where item[MediaAttributeKey.mediaType.rawValue] == MediaAttributeValue.video.rawValue {
            self.isAudioOnly = false
            if !checkDeviceMediaMuted(media: item) {
                self.videoMuted = false
                break
            }
        }

        self.audioMuted = true
        for (item) in self.mediaList where (item[MediaAttributeKey.mediaType.rawValue] == MediaAttributeValue.audio.rawValue && !checkDeviceMediaMuted(media: item)) {
            self.audioMuted = false
            break
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
    }

    func getDisplayName() -> String {
        if !self.displayName.isEmpty {
            return self.displayName
        } else if !self.registeredName.isEmpty {
            return self.registeredName
        }
        return self.paricipantHash()
    }

    func isExists() -> Bool {
        return self.state != .over && self.state != .inactive && self.state != .failure && self.state != .busy
    }

    func isActive() -> Bool {
        return self.state == .connecting || self.state == .ringing || self.state == .current
    }

    func isCurrent() -> Bool {
        return self.state == .current || self.state == .hold ||
            self.state == .unhold || self.state == .ringing
    }

    func updateParticipantsCallId(callId: String) {
        participantsCallId.removeAll()
        participantsCallId.insert(callId)
    }

    func updateWith(callId: String, callDictionary: [String: String], participantId: String) {
        self.update(withDictionary: callDictionary, withMedia: self.mediaList)
        self.participantUri = participantId
        self.callId = callId
        self.updateParticipantsCallId(callId: callId)
    }
}
