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
 The announcement of a document, in the conversation it was written in.

 The name shown is the one the daemon holds, not the one in the commit: a
 document can be renamed, and an announcement that keeps for ever the name its
 document was born with names something that no longer exists.
 */
class CollabDocMessageVM: ObservableObject {

    let message: MessageModel
    private let contextMenuState: PublishSubject<State>
    private let disposeBag = DisposeBag()

    @Published var name: String
    /**
     Whether the document this announces is gone for every member.

     Read from the message itself: the announcement of a document can only ever
     be edited to retire it, so an edited announcement means the document is
     gone. Asking the daemon instead would walk the conversation log once per
     row that scrolls by.
     */
    @Published var removed: Bool

    @Published var waitingToBeRead = false

    /**
     Whether a rename has been applied, after which a fetched name is stale.

     The name is asked for once, and renames arrive on their own; the answer
     comes off the daemon's queue and a rename off the delivery queue, with
     nothing ordering the two. An answer given before a rename can be delivered
     after one, and would put back a name the document no longer has. Both
     writes are made on the main queue, so reading this there needs no lock.
     */
    private var renameApplied = false

    var documentId: String {
        return self.message.collabDocumentId
    }

    init(message: MessageModel, contextMenuState: PublishSubject<State>) {
        self.message = message
        self.contextMenuState = contextMenuState
        self.name = message.collabDocumentName.isEmpty ? L10n.Collab.untitled
            : message.collabDocumentName
        self.removed = message.isMessageDeleted()
    }

    func messageUpdated() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.message.isMessageDeleted() else { return }
            self.removed = true
        }
    }

    /**
     Asks the daemon for the document's current name, and follows renames.

     Called once the conversation is known, which the message alone does not
     say: a message carries its author and its document, not the conversation
     it was committed to.
     */
    func follow(accountId: String, conversationId: String, service: CollaborationService) {
        let documentId = self.documentId
        guard !documentId.isEmpty else { return }
        service.name(accountId: accountId, conversationId: conversationId, documentId: documentId)
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] name in
                guard let self = self, !name.isEmpty, !self.renameApplied else { return }
                self.name = name
            })
            .disposed(by: self.disposeBag)
        service.documentsRenamed
            .filter {
                $0.accountId == accountId && $0.conversationId == conversationId
                    && $0.documentId == documentId
            }
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] renamed in
                guard let self = self, !renamed.value.isEmpty else { return }
                self.renameApplied = true
                self.name = renamed.value
            })
            .disposed(by: self.disposeBag)
        service.isWaitingToBeRead(forAccount: accountId,
                                  conversationId: conversationId,
                                  documentId: documentId)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] waiting in
                self?.waitingToBeRead = waiting
            })
            .disposed(by: self.disposeBag)
        service.removals(forAccount: accountId,
                         conversationId: conversationId,
                         documentId: documentId)
            // Only a removal for every member retires the announcement. One that
            // took the document off this device alone leaves it announced and
            // leaves this message live: opening it is what fetches it back.
            .filter { $0 }
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in
                self?.removed = true
            })
            .disposed(by: self.disposeBag)
    }

    func open() {
        guard !self.documentId.isEmpty, !self.removed else { return }
        self.contextMenuState.onNext(
            ContextMenu.openCollabDocument(documentId: self.documentId, name: self.name))
    }
}
