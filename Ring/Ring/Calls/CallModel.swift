/*
 *  Copyright (C) 2017 Savoir-faire Linux Inc.
 *
 *  Author: Silbino Gonçalves Matado <silbino.gmatado@savoirfairelinux.com>
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

class CallModel {

    let callId: String
    var dateReceived: Date!
    var fromRingId: String!
    var state: CallState = .unknown
    var displayName: String!
    var registeredName: String!
    let accountId: String!
    var audioMuted: Bool!
    var videoMuted: Bool!

    //Call detail keys
    fileprivate static let callTypeKey = "CALL_TYPE"
    fileprivate static let peerNumberKey = "PEER_NUMBER"
    fileprivate static let registeredNameKey = "REGISTERED_NAME"
    fileprivate static let displayNameKey = "DISPLAY_NAME"
    fileprivate static let confIdKey = "CONF_ID"
    fileprivate static let timeStampStartKey = "TIMESTAMP_START"
    fileprivate static let accountIdKey = "ACCOUNTID"
    fileprivate static let peerHoldingKey = "PEER_HOLDING"
    fileprivate static let audioMutedKey = "AUDIO_MUTED"
    fileprivate static let videoMutedKey = "VIDEO_MUTED"
    fileprivate static let videoSourceKey = "VIDEO_SOURCE"

    init(withCallId callId: String, valuesFromDictionary dictionary: [String: String]) {
        self.callId = callId

        if let fromRingId = dictionary[CallModel.peerNumberKey]?.components(separatedBy: "@").first {
            self.fromRingId = fromRingId
        } else {
            self.fromRingId = ""
        }

        if let accountId = dictionary[CallModel.accountIdKey] {
            self.accountId = accountId
        } else {
            self.accountId = ""
        }

        self.update(withDictionary: dictionary)

    }

    func update(withDictionary dictionary: [String: String]) {

        self.dateReceived = Date()

        if let displayName = dictionary[CallModel.displayNameKey] {
            self.displayName = displayName
        } else {
            self.displayName = ""
        }

        if let registeredName = dictionary[CallModel.registeredNameKey] {
            self.registeredName = registeredName
        } else {
            self.registeredName = ""
        }

        if let videoMuted = dictionary[CallModel.videoMutedKey]?.toBool() {
            self.videoMuted = videoMuted
        } else {
            self.videoMuted = false
        }

        if let audioMuted = dictionary[CallModel.audioMutedKey]?.toBool() {
            self.audioMuted = audioMuted
        } else {
            self.audioMuted = false
        }
    }
}
