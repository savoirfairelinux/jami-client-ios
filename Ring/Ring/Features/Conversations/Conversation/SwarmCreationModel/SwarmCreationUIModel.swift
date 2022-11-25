//
//  SwiftCreationUIModel.swift
//  Ring
//
//  Created by Binal Ahiya on 2022-11-16.
//  Copyright © 2022 Savoir-faire Linux. All rights reserved.
//

import Foundation
import RxSwift
import RxRelay
import SwiftUI

class SwarmCreationUIModel: ObservableObject {
    @Published var participantsRows = [ParticipantRow]()
    var filteredArray = [ParticipantRow]()
    let disposeBag = DisposeBag()
    let strSearchText = BehaviorRelay<String>(value: "")
    private let accountId: String
    private let conversationService: ConversationsService
    private var swarmInfo: SwarmInfo
    var swarmCreated: (() -> Void)

    @Published var swarmName: String = ""
    @Published var swarmDescription: String = ""
    @Published var imageData: Data = (UIImage(asset: Asset.addAvatar)?.convertToData(ofMaxSize: 1))!
    @Published var selections: [String] = []
    @Published var maximumLimit: Int = 8

    required init(with injectionBag: InjectionBag, accountId: String, swarmCreated: @escaping (() -> Void)) {
        self.swarmCreated = swarmCreated
        self.conversationService = injectionBag.conversationsService
        self.accountId = accountId
        self.swarmInfo = SwarmInfo(injectionBag: injectionBag, accountId: accountId)
        self.strSearchText.subscribe { searchText in
            if !searchText.isEmpty {
                let flatArr = self.filteredArray.compactMap { $0 }
                self.participantsRows = flatArr.filter { (item) -> Bool in
                    return item.match(string: searchText)
                }
            } else {
                self.participantsRows = self.filteredArray
            }
        } onError: { _ in

        }
        .disposed(by: disposeBag)

        self.swarmInfo.contacts.subscribe { infos in
            self.participantsRows = [ParticipantRow]()
            for info in infos {
                let participant = ParticipantRow(participantData: info)
                self.participantsRows.append(participant)
                self.filteredArray.append(participant)
            }
        } onError: { _ in

        }
        .disposed(by: self.disposeBag)
        injectionBag
            .contactsService
            .contacts
            .asObservable()
            .subscribe { contacts in
                self.swarmInfo.addContacts(contacts: contacts)
            } onError: { _ in
            }
            .disposed(by: self.disposeBag)

    }

    func createTheSwarm() {
        var info = [String: String]()
        let conversationId = self.conversationService.startConversation(accountId: accountId)
        let defaultImageData = UIImage(asset: Asset.addAvatar)?.convertToData(ofMaxSize: 1)
        let strImage = imageData.base64EncodedString()

        if !strImage.isEmpty && imageData != defaultImageData {
            info[ConversationAttributes.avatar.rawValue] = strImage
        }
        if !swarmName.isEmpty {
            info[ConversationAttributes.title.rawValue] = swarmName
        }
        if !swarmDescription.isEmpty {
            info[ConversationAttributes.description.rawValue] = swarmDescription
        }
        if !info.isEmpty {
            self.conversationService.updateConversationInfos(accountId: accountId, conversationId: conversationId, infos: info)
        }
        for participant in selections {
            self.conversationService.addConversationMember(accountId: accountId, conversationId: conversationId, memberId: participant)

        }
        // self.swarmCreated()
    }

}
