/*
*  Copyright (C) 2019 Savoir-faire Linux Inc.
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

import RxSwift
import RxCocoa

class ConferenceParticipantViewModel {
    let call: CallModel
    let callsSercive: CallsService
    let profileService: ProfilesService
    let accountService: AccountsService
    lazy var observableCall = {
        self.callsSercive.currentCall(callId: call.callId)
    }()
    let disposeBag = DisposeBag()

    init(with call: CallModel, injectionBag: InjectionBag) {
        self.call = call
        self.callsSercive = injectionBag.callService
        self.profileService = injectionBag.profileService
        self.accountService = injectionBag.accountService
    }

    lazy var contactImageData: Observable<Profile>? = {
        guard let account = self.accountService.getAccount(fromAccountId: call.accountId) else {
            return nil
        }
        let type = account.type == AccountType.sip ? URIType.sip : URIType.ring
        guard let uriString = JamiURI.init(schema: type,
                  infoHach: call.participantUri,
                  account: account).uriString else {return nil}
        return self.profileService.getProfile(uri: uriString,
                                              createIfNotexists: true, accountId: account.id)
    }()

    lazy var displayName: Driver<String> = {
        var name = self.call.displayName.isEmpty ? self.call.registeredName : self.call.displayName
        name = name.isEmpty ? self.call.paricipantHash() : name
        return Observable.just(name).asDriver(onErrorJustReturn: "")
    }()

    lazy var removeView: Observable<Bool> = {
        return self.observableCall
        .startWith(call)
            .map({ callModel in
                return (callModel.state == .over ||
                    callModel.state == .failure ||
                    callModel.state == .hungup ||
                    callModel.state == .busy)
            })
    }()

    func cancelCall() {
        self.callsSercive.hangUp(callId: call.callId)
            .subscribe(onCompleted: {
            }).disposed(by: disposeBag)
    }
}
