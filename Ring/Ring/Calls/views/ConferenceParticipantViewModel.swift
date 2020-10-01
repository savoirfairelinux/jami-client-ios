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
    private let call: CallModel? // for conference master call is nil
    private let callsSercive: CallsService
    private let profileService: ProfilesService
    private let accountService: AccountsService
    private let isMasterCall: Bool
    private let disposeBag = DisposeBag()

    private lazy var contactImageData: Observable<String?> = {
        guard let account = self.accountService.currentAccount else {
            return Observable.just(nil)
        }
        guard let call = call else {
            return self.profileService.getAccountProfile(accountId: account.id).map { profile in
                if let alias = profile.alias, !alias.isEmpty {
                    self.displayName.accept(alias)
                }
                return profile.photo
            }
        }
        let type = account.type == AccountType.sip ? URIType.sip : URIType.ring
        guard let uriString = JamiURI.init(schema: type,
                                           infoHach: call.participantUri,
                                           account: account).uriString else { return Observable.just(nil) }
        return profileService.getProfile(uri: uriString,
                                         createIfNotexists: false,
                                         accountId: account.id)
            .map { profile in
                if let alias = profile.alias, !alias.isEmpty {
                    self.call?.displayName = alias
                    self.displayName.accept(alias)
                }
                return profile.photo
            }
    }()

    private lazy var displayName: BehaviorRelay<String> = {
        var initialName = ""
        if let call = call {
            initialName = call.getDisplayName()
        } else if let account = self.accountService.currentAccount {
            initialName = account.registeredName
        }
        return BehaviorRelay<String>(value: initialName)
    }()

    lazy var removeView: Observable<Bool>? = {
        guard let call = call else { return nil }
        return self.callsSercive.currentCall(callId: call.callId )
        .startWith(call)
            .map({ callModel in
                return (callModel.state == .over ||
                    callModel.state == .failure ||
                    callModel.state == .hungup ||
                    callModel.state == .busy)
            })
    }()

    lazy var avatarObservable: Observable<(String?, String?)> = {
        return Observable<(String?, String?)>
            .combineLatest(self.contactImageData, self.displayName.asObservable()) { image, name in
                return (image, name)
            }
    }()

    init(with call: CallModel?, injectionBag: InjectionBag) {
        self.call = call
        self.callsSercive = injectionBag.callService
        self.profileService = injectionBag.profileService
        self.accountService = injectionBag.accountService
        self.isMasterCall = call == nil
    }

    func getName() -> String {
        guard call != nil else {
            return L10n.Account.me
        }
        return self.displayName.value
    }

    func getCallId() -> String? {
        return self.call?.callId
    }

    func cancelCall() {
        guard let call = self.call else { return }
        self.callsSercive.hangUp(callId: call.callId)
            .subscribe(onCompleted: { })
            .disposed(by: disposeBag)
    }
}
