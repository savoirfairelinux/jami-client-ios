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
    private let accountService: AccountsService
    private let nameService: NameService
    private let profileService: ProfilesService
    private let conversationService: ConversationsService

    var conversation: ConversationModel! {
        didSet {
            if !shouldTriggerDescriptionDidSet {
                description = conversation.description
                shouldTriggerDescriptionDidSet = true
            }
            self.participantList = self.conversation?.getParticipants() ?? []
        }
    }
    var title: String {
        if let title = conversation?.title,
           title.isEmpty {
            return title
        } else {
            //            participantList.compactMap({})
            return ""
        }
    }
    var description: String = "" {
        didSet {
            if shouldTriggerDescriptionDidSet {
                // ToDo: update swarm
            }
        }
    }
    var swarmType: String {
        switch conversation.type {
        case .oneToOne:
            return "Private swarm"
        case .adminInvitesOnly:
            return "Admin invites only"
        case .invitesOnly:
            return "Private group swarm"
        case .publicChat:
            return "Public group swarm"
        default:
            return "Others"
        }
    }
    var id: String {
        return conversation.id
    }
    private var shouldTriggerDescriptionDidSet: Bool = false
    @Published var participantList: [ConversationParticipant] = []

    var profileImageLeft: String = "person.crop.circle.fill"
    var profileImageRight: String = "person.crop.circle.fill"

    required init(with injectionBag: InjectionBag) {
        self.accountService = injectionBag.accountService
        self.conversationService = injectionBag.conversationsService
        self.nameService = injectionBag.nameService
        self.profileService = injectionBag.profileService
        self.getSwarmInfo()
    }

    //    private func nameLookup(id: String) {
    //        nameService.usernameLookupStatus
    //            .filter({ lookupNameResponse in
    //                return lookupNameResponse.address != nil &&
    //                    lookupNameResponse.address == id
    //            })
    //            .asObservable()
    //            .take(1)
    //            .subscribe(onNext: { [weak self] lookupNameResponse in
    //                print("XXXX => \(lookupNameResponse.name)")
    //                //                guard let self = self, let message = message else { return }
    //                // if we have a registered name then we should update the value for it
    //                //                if let name = lookupNameResponse.name, !name.isEmpty {
    //                //                    //                    self.updateName(name: name, id: id, message: message)
    //                //                } else if self.names[id] == nil {
    //                //                    //                    self.updateName(name: id, id: id, message: message)
    //                //                }
    //                //                if let username = self.names[id], self.avatars[id] == nil {
    //                //                    let image = UIImage.createContactAvatar(username: username)
    //                //                    //                    self.updateAvatar(image: image, id: id, message: message)
    //                //                }
    //            })
    //            .disposed(by: disposeBag)
    //        //        self.nameService.lookupAddress(withAccount: accountId, nameserver: "", address: id)
    //
    //    }

    private func getSwarmInfo() {
        if let conversationId = conversation?.id,
           let currentAccount = self.accountService.currentAccount,
           let accountURI = AccountModelHelper(withAccount: currentAccount).uri,
           let conversation = self.conversationService.getSwarmInfo(conversationId: conversationId, accountId: conversation.accountId, accountURI: accountURI) {
            self.conversation = conversation
        }
    }
}
