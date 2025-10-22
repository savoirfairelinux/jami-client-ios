/*
 * Copyright (C) 2023-2025 Savoir-faire Linux Inc.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA.
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
        return account.jamiId == participantId
    }

    func isHostCall(sinkId: String) -> Bool {
        return sinkId.contains("host")
    }

    func isLocalModerator(info: ConferenceParticipant) -> Bool {
        guard let account = self.accountService.currentAccount else { return false }
        return info.isModerator && info.uri == account.jamiId
    }

    func isLocalHost(info: ConferenceParticipant) -> Bool {
        guard let uri = info.uri, !uri.isEmpty else {
            return true
        }
        guard let account = self.accountService.currentAccount else { return false }
        return uri == account.jamiId
    }

    func getItemsForConferenceFor(participant: ConferenceParticipant,
                                  local: ConferenceParticipant,
                                  conferenceId: String, layout: CallLayout) -> [MenuItem] {
        guard let uri = participant.uri else { return [] }
        let active = participant.isActive
        let isHandRised = participant.isHandRaised
        // menu for local call
        if self.isLocalCall(participantId: uri) || uri.isEmpty {
            return menuItemsManager.getMenuItemsForLocalCall(layout: layout, active: active, isHandRised: isHandRised)
        }
        let isLocalModerator = local.isModerator
        let isLocalHost = local.sinkId.contains("host")
        let role: RoleInCall = isLocalHost ? .host : (isLocalModerator ? .moderator : .regular)
        let isParticipantHost = isHostCall(sinkId: participant.sinkId)

        let items = menuItemsManager.getMenuItemsFor(isHost: isParticipantHost, layout: layout, active: active, role: role, isHandRised: isHandRised)
        return items
    }

    func setActiveParticipant(participantId: String, maximize: Bool, conferenceId: String) {
        self.callService.setActiveParticipant(conferenceId: conferenceId, maximixe: maximize, jamiId: participantId)
    }

    func muteParticipant(participantId: String, active: Bool, conferenceId: String,
                         device: String, streamId: String) {
        guard let account = self.accountService.currentAccount else { return }
        let jamiId = participantId.isEmpty ? account.jamiId : participantId
        self.callService.muteStream(confId: conferenceId, participantId: jamiId, device: device, accountId: account.id, streamId: streamId, state: active)
    }

    func setModeratorParticipant(participantId: String, active: Bool, conferenceId: String) {
        self.callService.setModeratorParticipant(confId: conferenceId, participantId: participantId, active: active)
    }

    func hangupParticipant(participantId: String, device: String, conferenceId: String) {
        self.callService.hangupParticipant(confId: conferenceId, participantId: participantId, device: device)
    }

    func lowerHandFor(participantId: String, conferenceId: String, deviceId: String) {
        guard let account = self.accountService.currentAccount else { return }
        self.callService.setRaiseHand(confId: conferenceId, participantId: participantId, state: false, accountId: account.id, deviceId: deviceId)
    }

    func toggleRaiseHand(state: Bool, conferenceId: String, deviceId: String) {
        guard let account = self.accountService.currentAccount else { return }
        self.callService.setRaiseHand(confId: conferenceId, participantId: account.jamiId, state: state, accountId: account.id, deviceId: deviceId)
    }

}
