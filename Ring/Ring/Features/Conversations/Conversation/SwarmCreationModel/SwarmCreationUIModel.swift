/*
 *  Copyright (C) 2022 Savoir-faire Linux Inc.
 *
 *  Author: Binal Ahiya <binal.ahiya@savoirfairelinux.com>
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
    var swarmCreated: ((Bool) -> Void)

    @Published var swarmName: String = ""
    @Published var swarmDescription: String = ""
    @Published var imageData: Data = Data()
    @Published var selections: [String] = []
    @Published var maximumLimit: Int = 8

    required init(with injectionBag: InjectionBag, accountId: String, swarmCreated: @escaping ((Bool) -> Void)) {
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

        self.swarmInfo.contacts
            .observe(on: MainScheduler.instance)
            .subscribe { infos in
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

        if !imageData.isEmpty {
            info[ConversationAttributes.avatar.rawValue] = imageData.base64EncodedString()
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
        _ = self.swarmCreated(true)
    }

}
