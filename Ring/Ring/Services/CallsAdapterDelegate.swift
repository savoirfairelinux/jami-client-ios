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

@objc protocol CallsAdapterDelegate {
    func didChangeCallState(withCallId callId: String, state: String, stateCode: NSInteger)
    func didReceiveMessage(withCallId callId: String, fromURI uri: String, message: [String: String])
    func receivingCall(withAccountId accountId: String, callId: String, fromURI uri: String)
    func callPlacedOnHold(withCallId callId: String, holding: Bool)
    func audioMuted(call callId: String, mute: Bool)
    func videoMuted(call callId: String, mute: Bool)
    func conferenceCreated(conference conferenceID: String)
    func conferenceChanged(conference conferenceID: String, state: String)
    func conferenceRemoved(conference conferenceID: String)
    func conferenceInfoUpdated(conference conferenceID: String, info: [[String: String]])
}
