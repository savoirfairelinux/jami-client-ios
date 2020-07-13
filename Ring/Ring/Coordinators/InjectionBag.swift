/*
 *  Copyright (C) 2017-2020 Savoir-faire Linux Inc.
 *
 *  Author: Thibault Wittemberg <thibault.wittemberg@savoirfairelinux.com>
 *  Author: Raphaël Brulé <raphael.brule@savoirfairelinux.com>
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

/// We can centralize in this bag every service that is to be used by every layer of the app
class InjectionBag {

    let daemonService: DaemonService
    let accountService: AccountsService
    let nameService: NameService
    let conversationsService: ConversationsService
    let contactsService: ContactsService
    let presenceService: PresenceService
    let networkService: NetworkService
    let callService: CallsService
    let videoService: VideoService
    let audioService: AudioService
    let dataTransferService: DataTransferService
    let profileService: ProfilesService
    let callsProvider: CallsProviderDelegate
    let locationSharingService: LocationSharingService

    init (withDaemonService daemonService: DaemonService,
          withAccountService accountService: AccountsService,
          withNameService nameService: NameService,
          withConversationService conversationService: ConversationsService,
          withContactsService contactsService: ContactsService,
          withPresenceService presenceService: PresenceService,
          withNetworkService networkService: NetworkService,
          withCallService callService: CallsService,
          withVideoService videoService: VideoService,
          withAudioService audioService: AudioService,
          withDataTransferService dataTransferService: DataTransferService,
          withProfileService profileService: ProfilesService,
          withCallsProvider callsProvider: CallsProviderDelegate,
          withLocationSharingService locationSharingService: LocationSharingService) {
        self.daemonService = daemonService
        self.accountService = accountService
        self.nameService = nameService
        self.conversationsService = conversationService
        self.contactsService = contactsService
        self.presenceService = presenceService
        self.networkService = networkService
        self.callService = callService
        self.videoService = videoService
        self.audioService = audioService
        self.dataTransferService = dataTransferService
        self.profileService = profileService
        self.callsProvider = callsProvider
        self.locationSharingService = locationSharingService
    }
}
