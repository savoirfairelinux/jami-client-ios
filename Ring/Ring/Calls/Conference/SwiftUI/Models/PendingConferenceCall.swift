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
import RxSwift
import SwiftUI

class PendingConferenceCall {
    @Published var name = ""

    let id: String
    let profileInfo: ParticipantProfileInfo
    var info: ConferenceParticipant
    let disposeBag = DisposeBag()
    let callsService: CallsService
    let avatarProvider: AvatarProvider

    init(info: ConferenceParticipant, injectionBag: InjectionBag) {
        self.info = info
        self.id = info.sinkId
        self.callsService = injectionBag.callService
        self.profileInfo = ParticipantProfileInfo(
            injectionBag: injectionBag, info: info
        )
        self.avatarProvider = AvatarProvider(
            profileService: injectionBag.profileService,
            size: Constants.defaultAvatarSize,
            avatar: self.profileInfo.avatarData.asObservable(),
            displayName: self.profileInfo.displayName.asObservable(),
            isGroup: false
        )

        // name binding for row label remains
        self.profileInfo.displayName
            .observe(on: MainScheduler.instance)
            .startWith(self.profileInfo.displayName.value)
            .filter { !$0.isEmpty }
            .subscribe(onNext: { [weak self] name in
                self?.name = name
            })
            .disposed(by: disposeBag)
    }

    func stopPendingCall() {
        guard let call = self.callsService.call(callID: self.id) else { return }
        self.callsService.stopCall(call: call)
    }
}
