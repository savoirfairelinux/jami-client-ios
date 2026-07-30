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

    @Published var documents = [CollaborativeDocument]()
    @Published var failed = false

    init(with injectionBag: InjectionBag, accountId: String, conversationId: String) {
        self.collaborationService = injectionBag.collaborationService
        self.accountId = accountId
        self.conversationId = conversationId
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
