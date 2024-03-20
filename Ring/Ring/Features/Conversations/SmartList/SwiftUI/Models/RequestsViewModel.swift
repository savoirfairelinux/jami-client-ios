/*
 *  Copyright (C) 2024 Savoir-faire Linux Inc.
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
import SwiftUI
import Combine
import RxSwift
import RxRelay

class RequestViewModel: ObservableObject {
    @Published var avatar: UIImage?
    @Published var bestName: String = "" // Name to be shown in the request list. It is either the swarm title or the names of every participant in the conversation.
    var requestName = BehaviorRelay(value: "") // Name to be shown in the requests widget title on the smartList. It is either the swarm title or the name of the first participant. The request widget title is a name for every request, separated by commas.
    let request: RequestModel
    var registeredNames = [String: String]() // Dictionary of jamiId and registered name
    let nameService: NameService
    let disposeBag = DisposeBag()

    init(request: RequestModel, nameService: NameService) {
        self.request = request
        self.nameService = nameService
        self.setName()
    }

    private func setAvatar() {
        let newAvatar = createAvatar()
        updateAvatarOnMainThread(with: newAvatar)
    }

    private func setName() {
        if !request.name.isEmpty {
            updateNameOnMainThread(with: request.name)
            requestName.accept(request.name)
        } else {
            handleNoInvitationName()
        }
    }

    private func updateNameOnMainThread(with name: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.bestName = name
        }
    }

    private func updateAvatarOnMainThread(with image: UIImage) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.avatar = image
        }
    }

    private func updateNameFromRegistered() {
        let newBestName = constructNameFromRegisteredNames()
        updateNameOnMainThread(with: newBestName)
        if let name = registeredNames.first {
            requestName.accept(name.value.isEmpty ? name.key : name.value)
        }
    }

    private func constructNameFromRegisteredNames() -> String {
        return registeredNames.enumerated().map { index, element in
            let (jamiId, name) = element
            return name.isEmpty ? jamiId : name
        }.joined(separator: ", ")
    }

    private func createAvatar() -> UIImage {
        if let avatarData = request.avatar, let image = UIImage(data: avatarData) {
            return image
        } else if request.type == .contact {
            return UIImage.createContactAvatar(username: bestName)
        } else {
            return UIImage(systemName: "person.2") ?? UIImage()
        }
    }

    private func handleNoInvitationName() {
        initializeParticipantEntries()
        updateNameFromRegistered()
        performLookup()
    }

    private func initializeParticipantEntries() {
        // Create a dictionary of participant IDs and names, so names can be updated when lookup is finished.
        for participant in request.participants {
            registeredNames[participant.jamiId] = ""
        }
    }

    private func performLookup() {
        for jamiId in registeredNames.keys {
            lookupUserName(jamiId: jamiId)
        }
    }

    private func lookupUserName(jamiId: String) {
        nameService.usernameLookupStatus.asObservable()
            .filter { lookupNameResponse in
                return lookupNameResponse.address == jamiId
            }
            .take(1)
            .subscribe(onNext: { lookupNameResponse in
                if lookupNameResponse.state == .found && !lookupNameResponse.name.isEmpty {
                    self.registeredNames[jamiId] = lookupNameResponse.name
                    self.updateNameFromRegistered()
                }
            })
            .disposed(by: disposeBag)

        nameService.lookupAddress(withAccount: request.accountId, nameserver: "", address: jamiId)
    }

    func getIdentifier() -> String {
        return request.getIdentifier()
    }

    func onAppear() {
        if avatar == nil {
            setAvatar()
        }
    }
}

class RequestsViewModel: ObservableObject {
    @Published var requests = [RequestViewModel]()
    @Published var requestNames = ""
    @Published var unreadRequests = 0
    var title = L10n.Smartlist.invitationReceived
    let requestsService: RequestsService
    let conversationService: ConversationsService
    let accountService: AccountsService
    let nameService: NameService
    let disposeBag = DisposeBag()
    var titleDisposeBag = DisposeBag()

    init(injectionBag: InjectionBag) {
        self.requestsService = injectionBag.requestsService
        self.conversationService = injectionBag.conversationsService
        self.accountService = injectionBag.accountService
        self.nameService = injectionBag.nameService
        self.subscribeToRequests()
    }

    func subscribeToRequests() {
        let conversationsStream = conversationService.conversations
            .share()
            .startWith(conversationService.conversations.value)

        let requestsStream = requestsService.requests.asObservable()

        let unhandledRequests = Observable.combineLatest(requestsStream, conversationsStream) {
            [weak self] requests, conversations -> [RequestModel] in
            guard let self = self, let account = self.accountService.currentAccount else {
                return []
            }
            return self.filterRequestsNotInConversations(requests: requests, conversations: conversations, accountId: account.id)
        }

        unhandledRequests
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] newRequests in
                self?.processNewRequests(newRequests)
            })
            .disposed(by: disposeBag)
    }

    private func filterRequestsNotInConversations(requests: [RequestModel], conversations: [ConversationModel], accountId: String) -> [RequestModel] {
        let conversationIds = Set(conversations.map { $0.id })
        return requests.filter { $0.accountId == accountId && !conversationIds.contains($0.conversationId) }
    }

    private func processNewRequests(_ newRequests: [RequestModel]) {
        let newItems = self.findNewRequests(from: newRequests)
        let outdatedItems = self.findOutdatedRequests(comparedTo: newRequests)

        self.removeOutdatedItems(outdatedItems)
        self.addNewRequests(newItems)
        self.sortRequestsByReceivedDate()

        self.updateUnreadCount()
        if newItems.isEmpty && outdatedItems.isEmpty {
            // Skip updating requestNames if there are no new or outdated items.
            return
        }
        observeRequestNames()
    }

    private func findNewRequests(from newRequests: [RequestModel]) -> [RequestModel] {
        return newRequests.filter { newItem in
            !self.requests.contains { $0.request.getIdentifier() == newItem.getIdentifier() }
        }
    }

    private func findOutdatedRequests(comparedTo newRequests: [RequestModel]) -> [RequestViewModel] {
        return self.requests.filter { oldItem in
            !newRequests.contains { $0.getIdentifier() == oldItem.request.getIdentifier() }
        }
    }

    private func removeOutdatedItems(_ items: [RequestViewModel]) {
        let identifiers = Set(items.map { $0.request.getIdentifier() })
        self.requests.removeAll { identifiers.contains($0.request.getIdentifier()) }
    }

    private func addNewRequests(_ newRequests: [RequestModel]) {
        let newViewModels = newRequests.map { RequestViewModel(request: $0, nameService: self.nameService) }
        self.requests.append(contentsOf: newViewModels)
    }

    private func sortRequestsByReceivedDate() {
        self.requests.sort(by: { $0.request.receivedDate < $1.request.receivedDate })
    }

    private func updateUnreadCount() {
        self.unreadRequests = self.requests.count
    }

    private func observeRequestNames() {
        self.titleDisposeBag = DisposeBag()

        // Create a combined observable for request names
        Observable.combineLatest(requests.map { $0.requestName.asObservable() })
            .map { names in names.joined(separator: ", ") }
            .subscribe(onNext: { combinedNames in
                DispatchQueue.main.async { [weak self] in
                    self?.requestNames = combinedNames
                }
            })
            .disposed(by: self.titleDisposeBag)
    }
}
