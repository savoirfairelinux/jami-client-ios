//
//  SwarmSettingsViewModel.swift
//  Ring
//
//  Created by Alireza Toghiani on 11/4/22.
//  Copyright © 2022 Savoir-faire Linux. All rights reserved.
//

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
            self.swarmInfo = SwarmInfo(injectionBag: self.injectionBag, conversation: self.conversation.value, avatarHeight: 100)
            self.swarmInfo.finalAvatar
                .subscribe(onNext: { [weak self] newValue in
                    self?.finalAvatar = newValue
                })
                .disposed(by: disposeBag)
            self.swarmInfo.finalTitle
                .subscribe(onNext: { [weak self] newValue in
                    self?.finalTitle = newValue
                })
                .disposed(by: disposeBag)
            if !shouldTriggerDescriptionDidSet {
                description = swarmInfo.description.value
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
            if shouldTriggerDescriptionDidSet && !finalTitle.isEmpty {
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
            return members.filter({$0.role == .admin}).contains(where: {$0.jamiId == jamiId})
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
            if !finalTitle.isEmpty {
                conversationInfo[ConversationAttributes.title.rawValue] = title
            }
            self.conversationService.updateConversationInfos(accountId: accountId, conversationId: conversationId, infos: conversationInfo)
        }
    }
}
