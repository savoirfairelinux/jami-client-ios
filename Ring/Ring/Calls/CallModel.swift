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
    var duration: Int!
    var fromRingId: String!
    var state: CallState = .unknown

    var displayName: String!
    var registeredName: String!

    //Call detail keys
    fileprivate let callTypeKey = "CALL_TYPE"
    fileprivate let peerNumberKey = "PEER_NUMBER"
    fileprivate let registeredNameKey = "REGISTERED_NAME"
    fileprivate let displayNameKey = "DISPLAY_NAME"
    fileprivate let callStateKey = "CALL_STATE"
    fileprivate let confIdKey = "CONF_ID"
    fileprivate let timeStampStartKey = "TIMESTAMP_START"
    fileprivate let accountIdKey = "ACCOUNTID"
    fileprivate let peerHoldingKey = "PEER_HOLDING"
    fileprivate let audioMutedKey = "AUDIO_MUTED"
    fileprivate let videoMutedKey = "VIDEO_MUTED"
    fileprivate let videoSourceKey = "VIDEO_SOURCE"

    init(withCallId callId: String, valuesFromDictionary dictionary: [String: String]) {
        self.callId = callId
        self.update(withDictionary: dictionary)
    }

    func update(withDictionary dictionary: [String: String]) {

        self.dateReceived = Date()
        self.duration = 0
        self.fromRingId = ""

        if let displayName = dictionary[displayNameKey] {
            self.displayName = displayName
        } else {
            self.displayName = ""
        }

        if let registeredName = dictionary[registeredNameKey] {
            self.registeredName = registeredName
        } else {
            self.registeredName = ""
        }
    }
}
