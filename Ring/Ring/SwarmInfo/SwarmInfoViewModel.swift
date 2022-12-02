/*
 * Copyright (C) 2022 Savoir-faire Linux Inc. *
 *
 * Author: Alireza Toghiani Khorasgani alireza.toghiani@savoirfairelinux.com *
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version. *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details. *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

import UIKit
import RxSwift
import RxRelay
import RxCocoa

class SwarmInfoViewModel: Stateable, ViewModel, ObservableObject {

    private let disposeBag = DisposeBag()
    // MARK: - Rx Stateable
    private let stateSubject = PublishSubject<State>()
    lazy var state: Observable<State> = {
        return self.stateSubject.asObservable()
    }()
    let injectionBag: InjectionBag
    private let accountService: AccountsService
    private let nameService: NameService
    private let profileService: ProfilesService
    private let conversationService: ConversationsService

    @Published var swarmInfo: SwarmInfo!
    var conversation: BehaviorRelay<ConversationModel>! {
        didSet {
            self.swarmInfo = SwarmInfo(injectionBag: self.injectionBag, conversation: self.conversation.value, avatarHeight: 70)
            self.swarmInfo.finalAvatar
                .subscribe(onNext: { [weak self] newValue in
                    DispatchQueue.main.async {
                        self?.finalAvatar = newValue
                    }
                })
                .disposed(by: disposeBag)
            self.swarmInfo.finalTitle
                .subscribe(onNext: { [weak self] newValue in
                    DispatchQueue.main.async {
                        self?.finalTitle = newValue
                    }
                })
                .disposed(by: disposeBag)
            if !shouldTriggerDescriptionDidSet {
                description = swarmInfo.description.value
                title = swarmInfo.title.value
                shouldTriggerDescriptionDidSet = true
            }
        }
    }
    var description: String = "" {
        didSet {
            if shouldTriggerDescriptionDidSet {
                updateSwarmInfo()
            }
        }
    }
    var title: String = "" {
        didSet {
            if shouldTriggerDescriptionDidSet {
                updateSwarmInfo()
            }
        }
    }
    var isAdmin: Bool {
        get {
            guard let jamiId = accountService.currentAccount?.jamiId,
                  let members = swarmInfo?.participants.value else {
                return false
            }
            return members.filter({ $0.role == .admin }).contains(where: { $0.jamiId == jamiId })
        }
    }
    private var shouldTriggerDescriptionDidSet: Bool = false
    @Published var finalAvatar: UIImage = UIImage()
    @Published var finalTitle: String = ""

    required init(with injectionBag: InjectionBag) {
        self.injectionBag = injectionBag
        self.accountService = injectionBag.accountService
        self.conversationService = injectionBag.conversationsService
        self.nameService = injectionBag.nameService
        self.profileService = injectionBag.profileService
    }

    func updateSwarmInfo() {
        if let conversationId = conversation?.value.id,
           let accountId = conversation?.value.accountId {
            var conversationInfo = conversationService.getConversationInfo(conversationId: conversationId, accountId: accountId)
            conversationInfo[ConversationAttributes.description.rawValue] = description
            conversationInfo[ConversationAttributes.title.rawValue] = title
            self.conversationService.updateConversationInfos(accountId: accountId, conversationId: conversationId, infos: conversationInfo)
        }
    }

    func updateSwarmAvatar(image: UIImage?) {
        guard let image = image, let data = image.convertToDataForSwarm() else { return }
        if let conversationId = conversation?.value.id,
           let accountId = conversation?.value.accountId {
            var conversationInfo = conversationService.getConversationInfo(conversationId: conversationId, accountId: accountId)
            conversationInfo[ConversationAttributes.avatar.rawValue] = data.base64EncodedString()
            self.conversationService.updateConversationInfos(accountId: accountId, conversationId: conversationId, infos: conversationInfo)
            self.finalAvatar = image
        }
    }

    func leaveSwarm() {

    }

    func ignoreSwarm(isOn: Bool) {

    }
}
