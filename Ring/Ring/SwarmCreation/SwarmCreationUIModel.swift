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
    private var allRows = [ParticipantRow]()
    private var searchText = ""
    let disposeBag = DisposeBag()
    private let accountId: String
    private let conversationService: ConversationsService
    private let inviteCandidates: SwarmInviteCandidates
    var swarmCreated: ((_ conversationId: String, _ accountId: String) -> Void)

    @Published var swarmName: String = ""
    @Published var swarmDescription: String = ""
    @Published var image: UIImage?
    @Published var selections: [String] = []

    required init(with injectionBag: InjectionBag, accountId: String, strSearchText: BehaviorRelay<String>, swarmCreated: @escaping ((String, String) -> Void)) {
        self.swarmCreated = swarmCreated
        self.conversationService = injectionBag.conversationsService
        self.accountId = accountId
        self.inviteCandidates = SwarmInviteCandidates(injectionBag: injectionBag,
                                                      accountId: accountId,
                                                      members: .just([]))
        strSearchText
            .subscribe(onNext: { [weak self] searchText in
                guard let self = self else { return }
                self.searchText = searchText
                self.applySearch()
            })
            .disposed(by: disposeBag)

        self.inviteCandidates.candidates
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] infos in
                self?.updateCandidates(infos)
            })
            .disposed(by: self.disposeBag)
    }

    private func updateCandidates(_ infos: [ParticipantInfo]) {
        let existing = Dictionary(allRows.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        allRows = infos.map { existing[$0.jamiId] ?? ParticipantRow(participantData: $0) }
        let candidateIds = Set(allRows.map(\.id))
        selections.removeAll { !candidateIds.contains($0) }
        applySearch()
    }

    private func applySearch() {
        participantsRows = searchText.isEmpty
            ? allRows
            : allRows.filter { $0.match(string: searchText) }
    }

    func createTheSwarm() {
        var info = [String: String]()
        let conversationId = self.conversationService.startConversation(accountId: accountId)

        if let image = self.image, let data = image.convertToDataForSwarm() {
            info[ConversationAttributes.avatar.rawValue] = data.base64EncodedString()
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
        _ = self.swarmCreated(conversationId, accountId)
    }

    func getParticipant(id: String) -> ParticipantRow? {
        return allRows.first { participant in
            participant.id == id
        }
    }

    var initialSwarmName: String = ""
    var initialSwarmDescription: String = ""
    var initialImage: UIImage?

    func takeCurrentDataSnapshot() {
        initialSwarmName = self.swarmName
        initialSwarmDescription = self.swarmDescription
        initialImage = self.image
    }

    func setDataToInitial() {
        self.image = initialImage
        self.swarmName = initialSwarmName
        self.swarmDescription = initialSwarmName
    }

    var hasProfileImage: Bool {
        return image != nil
    }
}
