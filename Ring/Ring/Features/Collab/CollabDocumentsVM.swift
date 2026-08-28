/*
 * Copyright (C) 2026 Savoir-faire Linux Inc.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA.
 */

import Foundation
import RxSwift
import SwiftUI

/**
 The documents written together in one conversation.

 The list is read again rather than kept: a document created on another device
 arrives as a commit, and there is nothing to gain from a copy that has to be
 corrected from the same source it came from. The daemon says when a commit
 landed, and that is when the list is read again.
 */
class CollabDocumentsVM: ObservableObject {

    private let collaborationService: CollaborationService
    private let disposeBag = DisposeBag()

    let accountId: String
    let conversationId: String
    /// Who this device is, to tell the documents it may retire from the rest.
    private let localJamiId: String

    @Published var documents = [CollaborativeDocument]()
    @Published private(set) var waiting = Set<String>()
    @Published var failed = false
    @Published private var authorNames = [String: String]()
    /// What the alert says: creating and removing share it, and they fail for
    /// unrelated reasons.
    @Published var failureMessage = L10n.Collab.createError

    /// The naming prompt is raised over the whole screen, from `SwarmInfoView`,
    /// so what it shows cannot be the documents view's own state.
    @Published var isNaming = false
    @Published var pendingName = ""

    init(with injectionBag: InjectionBag,
         accountId: String,
         conversationId: String,
         participants: Observable<[ParticipantInfo]>) {
        self.collaborationService = injectionBag.collaborationService
        self.accountId = accountId
        self.conversationId = conversationId
        self.localJamiId = injectionBag.accountService
            .getAccount(fromAccountId: accountId)?.jamiId ?? ""
        self.subscribeDocumentChanges()
        self.subscribeAuthorNames(participants)
        self.subscribeDocumentsWaitingToBeRead()
    }

    private func subscribeDocumentsWaitingToBeRead() {
        self.collaborationService
            .documentsWaitingToBeRead(forAccount: self.accountId,
                                      conversationId: self.conversationId)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] waiting in
                self?.waiting = waiting
            })
            .disposed(by: self.disposeBag)
    }

    private func subscribeAuthorNames(_ participants: Observable<[ParticipantInfo]>) {
        participants
            .flatMapLatest { participants -> Observable<[String: String]> in
                guard !participants.isEmpty else { return .just([:]) }
                let names = participants.map { participant in
                    participant.finalName
                        .map { (participant.jamiId, $0) }
                }
                return Observable.combineLatest(names)
                    .map { Dictionary($0, uniquingKeysWith: { _, latest in latest }) }
            }
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] names in
                self?.authorNames = names
            })
            .disposed(by: self.disposeBag)
    }

    /**
     A document announced, renamed or removed on another device reaches this one
     as a daemon event, so the list says what the conversation holds while it is
     being looked at, not only when it was opened.

     A non-empty update is content for an editor that has the document open;
     nothing the list shows changes with it.
     */
    private func subscribeDocumentChanges() {
        self.collaborationService
            .changes(forAccount: self.accountId, conversationId: self.conversationId)
            .filter { $0.change == .notification }
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in
                self?.reload()
            })
            .disposed(by: self.disposeBag)

        let account = self.accountId
        let conversation = self.conversationId
        self.collaborationService
            .documentsRenamed
            .filter { event in
                event.accountId == account && event.conversationId == conversation
            }
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in
                self?.reload()
            })
            .disposed(by: self.disposeBag)

        self.collaborationService
            .documentsRemoved
            .filter { event in
                event.accountId == account && event.conversationId == conversation
            }
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in
                // Both removals change the list: one takes a document out of it,
                // the other only marks it as no longer held here.
                self?.reload()
            })
            .disposed(by: self.disposeBag)
    }

    func reload() {
        self.collaborationService
            .documents(accountId: self.accountId, conversationId: self.conversationId)
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] documents in
                self?.documents = documents
            })
            .disposed(by: self.disposeBag)
    }

    /// Starts a document and hands it back, by id and name, so it can be opened.
    func create(named name: String, then open: @escaping (String, String) -> Void) {
        self.collaborationService
            .createDocument(accountId: self.accountId,
                            conversationId: self.conversationId,
                            name: name)
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] document in
                guard let self = self else { return }
                self.reload()
                open(document.id, document.name)
            }, onFailure: { [weak self] _ in
                self?.fail(with: L10n.Collab.createError)
            })
            .disposed(by: self.disposeBag)
    }

    func startNaming() {
        self.pendingName = ""
        self.isNaming = true
    }

    func removals(for document: CollaborativeDocument) -> [CollabDocumentRemoval] {
        return CollabDocumentRemoval.available(for: document, localJamiId: localJamiId)
    }

    func perform(_ removal: CollabDocumentRemoval, on document: CollaborativeDocument) {
        switch removal {
        case .fromThisDevice: removeLocally(document)
        case .forEveryone: removeEverywhere(document)
        }
    }

    /// Retire a document for every member of the conversation.
    func removeEverywhere(_ document: CollaborativeDocument) {
        remove(document, failure: L10n.Collab.removeError) { [collaborationService, accountId, conversationId] in
            collaborationService.removeDocument(accountId: accountId,
                                                conversationId: conversationId,
                                                documentId: document.id)
        }
    }

    /// Drop a document from this device, leaving the other members with it.
    func removeLocally(_ document: CollaborativeDocument) {
        remove(document, failure: L10n.Collab.removeLocallyError) { [collaborationService, accountId, conversationId] in
            collaborationService.removeDocumentLocally(accountId: accountId,
                                                       conversationId: conversationId,
                                                       documentId: document.id)
        }
    }

    /**
     Nothing is dropped from the list here.

     The daemon reports every removal through `documentsRemoved`, this device's
     own included, and that one signal is what the list is rebuilt from: what the
     author sees is what the peers see.
     */
    private func remove(_ document: CollaborativeDocument,
                        failure message: String,
                        by call: @escaping () -> Single<Bool>) {
        call()
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] removed in
                guard !removed else { return }
                self?.fail(with: message)
            }, onFailure: { [weak self] _ in
                self?.fail(with: message)
            })
            .disposed(by: self.disposeBag)
    }

    private func fail(with message: String) {
        self.failureMessage = message
        self.failed = true
    }

    func isWaitingToBeRead(_ document: CollaborativeDocument) -> Bool {
        return self.waiting.contains(document.id)
    }

    func title(of document: CollaborativeDocument) -> String {
        return document.name.isEmpty ? L10n.Collab.untitled : document.name
    }

    func authorName(of document: CollaborativeDocument) -> String? {
        return Self.authorName(for: document.author,
                               resolved: self.authorNames,
                               localJamiId: self.localJamiId)
    }

    func detail(of document: CollaborativeDocument) -> String? {
        return Self.detail(authorName: self.authorName(of: document),
                           storedLocally: document.storedLocally)
    }

    static func detail(authorName: String?, storedLocally: Bool) -> String? {
        switch (authorName, storedLocally) {
        case let (author?, true): return L10n.Collab.createdBy(author)
        case let (author?, false): return L10n.Collab.createdByNotDownloaded(author)
        case (nil, true): return nil
        case (nil, false): return L10n.Collab.notDownloaded
        }
    }

    static func authorName(for author: String?,
                           resolved: [String: String],
                           localJamiId: String) -> String? {
        guard let author = author, !author.isEmpty else { return nil }
        let known = resolved[author].flatMap { $0.isEmpty || $0 == author ? nil : $0 }
        let name = known ?? String(author.prefix(8))
        guard !localJamiId.isEmpty, author == localJamiId else { return name }
        return name.withYourselfSuffix()
    }
}
