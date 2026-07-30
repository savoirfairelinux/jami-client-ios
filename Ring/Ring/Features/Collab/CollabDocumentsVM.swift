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

    @Published var documents = [CollaborativeDocument]()
    @Published var failed = false

    /// The naming prompt is raised over the whole screen, from `SwarmInfoView`,
    /// so what it shows cannot be the documents view's own state.
    @Published var isNaming = false
    @Published var pendingName = ""

    init(with injectionBag: InjectionBag, accountId: String, conversationId: String) {
        self.collaborationService = injectionBag.collaborationService
        self.accountId = accountId
        self.conversationId = conversationId
        self.subscribeDocumentChanges()
    }

    /**
     A document announced or renamed on another device reaches this one as a
     daemon event, so the list says what the conversation holds while it is
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
                    self.failed = true
                    return
                }
                self.reload()
                open(documentId, named)
            }, onFailure: { [weak self] _ in
                self?.failed = true
            })
            .disposed(by: self.disposeBag)
    }

    func startNaming() {
        self.pendingName = ""
        self.isNaming = true
    }

    func title(of document: CollaborativeDocument) -> String {
        return document.name.isEmpty ? L10n.Collab.untitled : document.name
    }

    func subtitle(of document: CollaborativeDocument) -> String {
        let date = DateFormatter.localizedString(
            from: Date(timeIntervalSince1970: TimeInterval(document.timestamp)),
            dateStyle: .medium,
            timeStyle: .none)
        guard let author = document.author, !author.isEmpty else { return date }
        let short = author.count > 8 ? String(author.prefix(8)) : author
        return L10n.Collab.createdBy(short) + " · " + date
    }
}
