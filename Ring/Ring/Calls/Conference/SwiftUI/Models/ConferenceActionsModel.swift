/*
 *  Copyright (C) 2023 Savoir-faire Linux Inc.
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

class ConferenceActionsModel {

    let accountService: AccountsService
    let callService: CallsService

    private let menuItemsManager = ConferenceMenuItemsManager()

    init(injectionBag: InjectionBag) {
        self.accountService = injectionBag.accountService
        self.callService = injectionBag.callService
    }

    func isLocalCall(participantId: String) -> Bool {
        guard let account = self.accountService.currentAccount else { return false }
        return account.jamiId == participantId.filterOutHost()
    }

    func isHostCall(sinkId: String) -> Bool {
        return sinkId.contains("host")
    }

    func isLocalModerator(conferenceId: String, info: ConferenceParticipant) -> Bool {
        guard let account = self.accountService.currentAccount else { return false }
        return info.isModerator && info.uri == account.jamiId
    }

    func getItemsForConferenceFor(participant: ConferenceParticipant, conferenceId: String, layout: CallLayout) -> [MenuItem] {
        guard let uri = participant.uri else { return [] }
        let active = participant.isActive
        let isHandRised = participant.isHandRaised
        // menu for local call
        if self.isLocalCall(participantId: uri) || uri.isEmpty {
            return menuItemsManager.getMenuItemsForLocalCall(layout: layout, active: active, isHandRised: isHandRised)
        }
        let isModerator = self.isLocalModerator(conferenceId: conferenceId, info: participant)
        let callIsHost = self.isHostCall(sinkId: participant.sinkId)
        let role: RoleInCall = callIsHost ? .host : (isModerator ? .moderator : .regular)

        let participantCall = self.callService.call(callID: conferenceId)

        return menuItemsManager.getMenuItemsFor(call: participantCall, isHost: callIsHost, layout: layout, active: active, role: role, isHandRised: isHandRised)
    }

    func setActiveParticipant(participantId: String, maximize: Bool, conferenceId: String) {
        self.callService.setActiveParticipant(conferenceId: conferenceId, maximixe: maximize, jamiId: participantId)
    }

    func muteParticipant(participantId: String, active: Bool, conferenceId: String) {
        self.callService.muteParticipant(confId: conferenceId, participantId: participantId, active: active)
    }

    func setModeratorParticipant(participantId: String, active: Bool, conferenceId: String) {
        self.callService.setModeratorParticipant(confId: conferenceId, participantId: participantId, active: active)
    }

    func hangupParticipant(participantId: String, device: String, conferenceId: String) {
        self.callService.hangupParticipant(confId: conferenceId, participantId: participantId, device: device)
    }

    func lowerHandFor(participantId: String, conferenceId: String) {
        self.callService.setRaiseHand(confId: conferenceId, participantId: participantId, state: false)
    }

    func togleRaiseHand(state: Bool, conferenceId: String) {
        guard let account = self.accountService.currentAccount else { return }
        self.callService.setRaiseHand(confId: conferenceId, participantId: account.jamiId, state: state)
    }

}
