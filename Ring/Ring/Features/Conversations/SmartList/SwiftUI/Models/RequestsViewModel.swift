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

enum RequestStatus {
    case pending
    case accepted
    case refused
    case banned

    func toString() -> String {
        switch self {
        case .pending:
            return ""
        case .accepted:
            return L10n.Invitations.accepted
        case .refused:
            return L10n.Invitations.declined
        case .banned:
            return L10n.Invitations.blocked
        }
    }

    func color() -> Color {
        switch self {
        case .pending:
            return Color(UIColor.white)
        case .accepted:
            return Color(UIColor.systemGreen)
        case .refused:
            return Color(UIColor.orange)
        case .banned:
            return Color(UIColor.systemRed)
        }
    }
}

enum RequestAction {
    case accept, discard, block
}

class RequestNameResolver: ObservableObject, Identifiable, Hashable {
    var bestName: String = "" // Name to be shown in the request list. It is either the swarm title or the names of every participant in the conversation.
    let id: String
    /*
     Name to be shown in the requests widget title on the smartList.
     It is either the swarm title or the name of the first participant.
     The request widget title is a name for every request,
     separated by commas.
     */
    var requestName = BehaviorRelay(value: "")
    let request: RequestModel
    var registeredNames = [String: String]() // Dictionary of jamiId and registered name
    let nameService: NameService
    let disposeBag = DisposeBag()
    var nameResolved = BehaviorRelay(value: false)

    init(request: RequestModel, nameService: NameService) {
        self.request = request
        self.id = request.getIdentifier()
        self.nameService = nameService
        self.setName()
    }

    private func setName() {
        if !request.name.isEmpty {
            updateNameOnMainThread(with: request.name)
            requestName.accept(request.name)
            self.nameResolved.accept(true)
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

    private func updateNameFromRegistered() {
        let newBestName = constructNameFromRegisteredNames()
        updateNameOnMainThread(with: newBestName)
        if let name = registeredNames.first {
            requestName.accept(name.value.isEmpty ? name.key : name.value)
        }
    }

    private func constructNameFromRegisteredNames() -> String {
        return registeredNames.enumerated()
            .map { _, element in
                let (jamiId, name) = element
                return name.isEmpty ? jamiId : name
            }
            .joined(separator: ", ")
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
                    self.nameResolved.accept(true)
                }
            })
            .disposed(by: disposeBag)

        nameService.lookupAddress(withAccount: request.accountId, nameserver: "", address: jamiId)
    }

    func getIdentifier() -> String {
        return request.getIdentifier()
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: RequestNameResolver, rhs: RequestNameResolver) -> Bool {
        return lhs.id == rhs.id
    }
}

class RequestRowViewModel: ObservableObject, Identifiable, Hashable {
    @Published var avatar: UIImage?
    @Published var receivedDate: String
    @Published var status: RequestStatus = .pending
    @Published var markedToRemove: Bool = false
    let avatarSize: CGFloat = 55
    let request: RequestModel
    let id: String
    let nameResolver: RequestNameResolver
    let disposeBag = DisposeBag()

    init(request: RequestModel, nameResolver: RequestNameResolver) {
        self.nameResolver = nameResolver
        self.id = request.getIdentifier()
        self.request = request
        self.receivedDate = request.receivedDate.conversationTimestamp()
        self.setAvatar()
        self.nameResolver.nameResolved
            .startWith(self.nameResolver.nameResolved.value)
            .subscribe(onNext: { [weak self] resolved in
                if resolved {
                    self?.setAvatar()
                }
            })
            .disposed(by: disposeBag)
    }

    private func setAvatar() {
        let newAvatar = createAvatar()
        updateAvatarOnMainThread(with: newAvatar)
    }

    private func updateAvatarOnMainThread(with image: UIImage) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.avatar = image
        }
    }

    private func createAvatar() -> UIImage {
        if let avatarData = nameResolver.request.avatar, let image = UIImage(data: avatarData) {
            return image
        } else if request.type == .contact {
            return UIImage.createContactAvatar(username: nameResolver.bestName, size: CGSize(width: avatarSize, height: avatarSize))
        } else {
            return UIImage.createSwarmAvatar(convId: nameResolver.request.conversationId, size: CGSize(width: avatarSize, height: avatarSize))
        }
    }

    func requestAccepted() {
        self.status = .accepted
    }

    func requestDiscarded() {
        self.status = .refused
    }

    func requestBlocked() {
        self.status = .banned
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: RequestRowViewModel, rhs: RequestRowViewModel) -> Bool {
        return lhs.id == rhs.id
    }
}

class RequestsViewModel: ObservableObject {
    @Published var requestsRow = [RequestRowViewModel]()
    @Published var requestNames = ""
    @Published var unreadRequests = 0
    @Published var requestViewOpened = false
    var requestsNameResolvers = ThreadSafeArray<RequestNameResolver>(label: "com.requestsNameResolvers")// requests and resolved name
    var title = L10n.Smartlist.invitationReceived

    let requestsService: RequestsService
    let conversationService: ConversationsService
    let accountService: AccountsService
    let contactsService: ContactsService
    let presenceService: PresenceService
    let injectionBar: InjectionBag
    let nameService: NameService

    let disposeBag = DisposeBag()
    var titleDisposeBag = DisposeBag()

    init(injectionBag: InjectionBag) {
        self.requestsService = injectionBag.requestsService
        self.conversationService = injectionBag.conversationsService
        self.accountService = injectionBag.accountService
        self.nameService = injectionBag.nameService
        self.contactsService = injectionBag.contactsService
        self.presenceService = injectionBag.presenceService
        self.injectionBar = injectionBag
        self.subscribeToNewRequests()
    }

    func subscribeToNewRequests() {
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
        if requestsNameResolvers.count() == 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self else { return }
                self.requestViewOpened = false
            }
        }
        if newItems.isEmpty && outdatedItems.isEmpty {
            // Skip updating requestNames if there are no new or outdated items.
            return
        }
        observeRequestNames()
    }

    private func findNewRequests(from newRequests: [RequestModel]) -> [RequestModel] {
        return newRequests.filter { newItem in
            !self.requestsNameResolvers.contains { $0.request.getIdentifier() == newItem.getIdentifier() }
        }
    }

    private func findOutdatedRequests(comparedTo newRequests: [RequestModel]) -> [RequestNameResolver] {
        return self.requestsNameResolvers.filter { oldItem in
            !newRequests.contains { $0.getIdentifier() == oldItem.request.getIdentifier() }
        }
    }

    private func removeOutdatedItems(_ items: [RequestNameResolver]) {
        let identifiers = Set(items.map { $0.request.getIdentifier() })
        self.requestsNameResolvers.removeAll { identifiers.contains($0.request.getIdentifier()) }
        self.markRowsForRemoval(with: identifiers)
    }

    private func markRowsForRemoval(with identifiers: Set<String>) {
        identifiers.forEach { identifier in
            for row in requestsRow where row.request.getIdentifier() == identifier {
                withAnimation(.easeInOut(duration: 0.2)) {
                    row.markedToRemove = true
                }
                self.scheduleRowRemoval(identifier)
            }
        }
    }

    private func scheduleRowRemoval(_ identifier: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self = self else { return }
            withAnimation(.easeInOut(duration: 0.5)) {
                self.requestsRow.removeAll { $0.request.getIdentifier() == identifier }
            }
        }
    }

    private func addNewRequests(_ newRequests: [RequestModel]) {
        let newViewModels = newRequests.map { RequestNameResolver(request: $0, nameService: self.nameService) }
        self.requestsNameResolvers.append(contentsOf: newViewModels)
        if requestViewOpened {
            for nameResolver in newViewModels {
                requestsRow.append(RequestRowViewModel(request: nameResolver.request, nameResolver: nameResolver))
            }
        }
    }

    private func sortRequestsByReceivedDate() {
        self.requestsNameResolvers.sort(by: { $0.request.receivedDate < $1.request.receivedDate })
    }

    private func updateUnreadCount() {
        self.unreadRequests = self.requestsNameResolvers.count()
    }

    private func observeRequestNames() {
        self.titleDisposeBag = DisposeBag()

        // Create a combined observable for request names
        Observable.combineLatest(requestsNameResolvers.map { $0.requestName.asObservable() })
            .map { names in names.joined(separator: ", ") }
            .subscribe(onNext: { combinedNames in
                DispatchQueue.main.async { [weak self] in
                    self?.requestNames = combinedNames
                }
            })
            .disposed(by: self.titleDisposeBag)
    }

    // MARK: - presenting requests list

    func presentRequests() {
        // When the list of requests is presented, maintain the same number of requests.
        // Create rows from the current requests so that the list does not change as requests are processed.
        generateRequestRows()
        requestViewOpened.toggle()
    }

    func generateRequestRows() {
        requestsRow = [RequestRowViewModel]()
        for nameResolver in requestsNameResolvers {
            requestsRow.append(RequestRowViewModel(request: nameResolver.request, nameResolver: nameResolver))
        }
    }

    // MARK: - request actions

    func accept(requestRow: RequestRowViewModel) {
        processRequest(requestRow, action: .accept) {
            if requestRow.request.isDialog(), let jamiId = requestRow.request.participants.first?.jamiId {
                self.presenceService.subscribeBuddy(withAccountId: requestRow.request.accountId, withJamiId: jamiId, withFlag: true)
            }
        }
    }

    func discard(requestRow: RequestRowViewModel) {
        processRequest(requestRow, action: .discard)
    }

    func block(requestRow: RequestRowViewModel) {
        processRequest(requestRow, action: .block) {
            guard let jamiId = requestRow.request.participants.first?.jamiId else { return }
            self.removeContactAndBan(jamiId: jamiId, accountId: requestRow.request.accountId)
        }
    }

    private func processRequest(_ requestRow: RequestRowViewModel, action: RequestAction, completion: (() -> Void)? = nil) {
        let requestServiceAction = (action == .accept) ? requestsService.acceptConverversationRequest : requestsService.discardConverversationRequest

        requestServiceAction(requestRow.request.conversationId, requestRow.request.accountId)
            .subscribe(
                onError: { error in
                    print("Error processing request: \(error.localizedDescription)")
                },
                onCompleted: { [weak requestRow] in
                    guard let requestRow = requestRow else { return }
                    switch action {
                    case .accept:
                        requestRow.requestAccepted()
                        completion?()
                    case .discard:
                        requestRow.requestDiscarded()
                    case .block:
                        requestRow.requestBlocked()
                        completion?()
                    }
                }
            )
            .disposed(by: disposeBag)
    }

    private func removeContactAndBan(jamiId: String, accountId: String) {
        contactsService.removeContact(withId: jamiId, ban: true, withAccountId: accountId)
            .subscribe()
            .disposed(by: disposeBag)
    }
}
