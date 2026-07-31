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
 corrected from the same source it came from.
 */
class CollabDocumentsVM: ObservableObject {

    private let collaborationService: CollaborationService
    private let disposeBag = DisposeBag()

    let accountId: String
    let conversationId: String
    /// Who this device is, to tell the documents it may retire from the rest.
    private let localJamiId: String

    @Published var documents = [CollaborativeDocument]()
    @Published var failed = false
    /// What the alert says: creating and removing share it, and they fail for
    /// unrelated reasons.
    @Published var failureMessage = L10n.Collab.createError

    init(with injectionBag: InjectionBag, accountId: String, conversationId: String) {
        self.collaborationService = injectionBag.collaborationService
        self.accountId = accountId
        self.conversationId = conversationId
        self.localJamiId = injectionBag.accountService
            .getAccount(fromAccountId: accountId)?.jamiId ?? ""
        self.collaborationService.documentsRemoved
            .filter { [accountId, conversationId] in
                $0.accountId == accountId && $0.conversationId == conversationId
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

    /**
     Starts a document and hands its identifier back so it can be opened.

     An empty identifier is how the daemon refuses; an editor opened on it
     would show a document that does not exist.
     */
    func create(named name: String, then open: @escaping (String, String) -> Void) {
        let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let named = title.isEmpty ? L10n.Collab.untitled : title
        self.collaborationService
            .createDocument(accountId: self.accountId,
                            conversationId: self.conversationId,
                            name: named,
                            mimeType: CollaborativeDocument.mimeRichText)
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] documentId in
                guard let self = self else { return }
                guard !documentId.isEmpty else {
                    self.fail(with: L10n.Collab.createError)
                    return
                }
                self.reload()
                open(documentId, named)
            }, onFailure: { [weak self] _ in
                self?.fail(with: L10n.Collab.createError)
            })
            .disposed(by: self.disposeBag)
    }

    /**
     Whether this device may retire a document for every member.

     Only its author may, and the daemon refuses anyone else: offering it to the
     others would promise what cannot happen.
     */
    func canRemoveEverywhere(_ document: CollaborativeDocument) -> Bool {
        guard let author = document.author, !author.isEmpty else { return false }
        return !localJamiId.isEmpty && author == localJamiId
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

    func title(of document: CollaborativeDocument) -> String {
        return document.name.isEmpty ? L10n.Collab.untitled : document.name
    }

    /**
     Who wrote it and when, and whether this device still holds it.

     An entry that is no longer held stays open-able: opening it is what brings
     it back, so it is told apart rather than dimmed.
     */
    func subtitle(of document: CollaborativeDocument) -> String {
        let date = DateFormatter.localizedString(
            from: Date(timeIntervalSince1970: TimeInterval(document.timestamp)),
            dateStyle: .medium,
            timeStyle: .none)
        var line = date
        if let author = document.author, !author.isEmpty {
            let short = author.count > 8 ? String(author.prefix(8)) : author
            line = L10n.Collab.createdBy(short) + " · " + date
        }
        guard document.storedLocally else {
            return line + " · " + L10n.Collab.notOnThisDevice
        }
        return line
    }
}
