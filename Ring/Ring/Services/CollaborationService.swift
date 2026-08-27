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

/// A collaborator's ephemeral state (cursor, selection) for a document.
struct AwarenessUpdate {
    let accountId: String
    let conversationId: String
    let documentId: String
    let peerId: String
    let clientId: UInt64
    let state: String
}

/// A change to a document's content, as the Y-CRDT update that carries it.
struct DocumentUpdate {
    let accountId: String
    let conversationId: String
    let documentId: String
    let update: Data
}

/// What a collaborative-document update signal means.
enum CollaborativeDocumentChange: Equatable {
    /// Bytes to merge into an open editor's CRDT replica.
    case update(Data)
    /// The document changed while no client here had it open; reopen it to fetch
    /// the content. This can also be used to mark the document unread.
    case notification
}

/// A content update or a change notification for a document.
struct DocumentChangeEvent {
    let accountId: String
    let conversationId: String
    let documentId: String
    let change: CollaborativeDocumentChange
}

/// A document was renamed, or an attachment was added to one.
struct DocumentEvent {
    let accountId: String
    let conversationId: String
    let documentId: String
    /// The new name, or the attachment's identifier.
    let value: String
}

/// A collaborator stopped editing a document.
struct ParticipantLeft {
    let accountId: String
    let conversationId: String
    let documentId: String
    let peerId: String
    let clientId: UInt64
}

/// A document is no longer held here.
struct DocumentRemoved {
    let accountId: String
    let conversationId: String
    let documentId: String
    /**
     True when its author retired it for every member, and nothing brings it
     back. False when this device alone dropped it: the other members keep it,
     and opening it again fetches it back.
     */
    let everywhere: Bool
}

/// What the daemon can refuse to do with a document.
enum CollaborationError: Error {
    /**
     The daemon declined to create the document, which it says by answering with
     no identifier: an editor opened on an empty one would show a document that
     does not exist.
     */
    case refused
}

/**
 Collaborative documents: their lifecycle, their content as Y-CRDT updates, and
 the ephemeral state their editors share.

 The daemon knows nothing of what a document holds. Updates cross this service
 as the bytes the editing engine produced, and awareness as an opaque string
 whose shape is agreed between clients.
 */
class CollaborationService {

    private let adapter: CollaborationAdapter
    private let disposeBag = DisposeBag()

    /**
     Calls into the daemon run here, off the caller's thread.

     Serial on purpose: opening a document, seeding a replica and closing it
     again are ordered against each other, and the daemon's own locks are
     nothing to contend for from several threads at once.
     */
    private let daemonScheduler = SerialDispatchQueueScheduler(
        internalSerialQueueName: "com.jami.collaboration.daemon"
    )

    /**
     Events are handed over off the daemon's thread.

     A subject calls its subscribers where it stands, and these are fed straight
     from the daemon's callbacks: a subscriber that reads a database, or asks
     the daemon something in turn, would be holding up the thread the daemon is
     waiting to have back. What each event carries is already a copy by then, so
     the daemon is free to go.
     */
    private let deliveryScheduler = ConcurrentDispatchQueueScheduler(qos: .userInitiated)

    private let unreadLock = NSLock()
    private var unreadDocumentIds = [String: Set<String>]()
    private var openDocumentKeys = Set<String>()
    private let unreadCountSubject = PublishSubject<(conversation: String, count: Int)>()

    private let documentChangeSubject = PublishSubject<DocumentChangeEvent>()
    private let awarenessSubject = PublishSubject<AwarenessUpdate>()
    private let participantLeftSubject = PublishSubject<ParticipantLeft>()
    private let renamedSubject = PublishSubject<DocumentEvent>()
    private let attachmentSubject = PublishSubject<DocumentEvent>()
    private let removedSubject = PublishSubject<DocumentRemoved>()

    lazy var documentChanges = documentChangeSubject.observe(on: deliveryScheduler)
    lazy var documentUpdates = documentChanges.compactMap { event -> DocumentUpdate? in
        guard case let .update(update) = event.change else { return nil }
        return DocumentUpdate(accountId: event.accountId,
                              conversationId: event.conversationId,
                              documentId: event.documentId,
                              update: update)
    }
    lazy var awarenessUpdates = awarenessSubject.observe(on: deliveryScheduler)
    lazy var participantsLeft = participantLeftSubject.observe(on: deliveryScheduler)
    lazy var documentsRenamed = renamedSubject.observe(on: deliveryScheduler)
    lazy var attachmentsAdded = attachmentSubject.observe(on: deliveryScheduler)
    lazy var documentsRemoved = removedSubject.observe(on: deliveryScheduler)

    init(withCollaborationAdapter adapter: CollaborationAdapter) {
        self.adapter = adapter
        CollaborationAdapter.delegate = self
    }

    // MARK: - Streams for one open document

    /// Updates for one open document, the form an editor subscribes to.
    func updates(forAccount accountId: String,
                 conversationId: String,
                 documentId: String) -> Observable<Data> {
        return documentUpdates
            .filter {
                $0.accountId == accountId && $0.conversationId == conversationId
                    && $0.documentId == documentId
            }
            .map { $0.update }
    }

    /// Every change signal for the collaborative documents in one conversation.
    func changes(forAccount accountId: String,
                 conversationId: String) -> Observable<DocumentChangeEvent> {
        return documentChangeSubject
            .filter {
                $0.accountId == accountId && $0.conversationId == conversationId
            }
            .observe(on: deliveryScheduler)
    }

    /**
     Every change signal for one document. A non-empty daemon payload is an
     update to merge; an empty payload is a notification that the document
     changed while it was not open here.
     */
    func changes(forAccount accountId: String,
                 conversationId: String,
                 documentId: String) -> Observable<CollaborativeDocumentChange> {
        return changes(forAccount: accountId, conversationId: conversationId)
            .filter { $0.documentId == documentId }
            .map { $0.change }
    }

    func awareness(forAccount accountId: String,
                   conversationId: String,
                   documentId: String) -> Observable<AwarenessUpdate> {
        return awarenessUpdates
            .filter {
                $0.accountId == accountId && $0.conversationId == conversationId
                    && $0.documentId == documentId
            }
    }

    func departures(forAccount accountId: String,
                    conversationId: String,
                    documentId: String) -> Observable<ParticipantLeft> {
        return participantsLeft
            .filter {
                $0.accountId == accountId && $0.conversationId == conversationId
                    && $0.documentId == documentId
            }
    }

    func attachments(forAccount accountId: String,
                     conversationId: String,
                     documentId: String) -> Observable<String> {
        return attachmentsAdded
            .filter {
                $0.accountId == accountId && $0.conversationId == conversationId
                    && $0.documentId == documentId
            }
            .map { $0.value }
    }

    /// Removals of one document, for a screen showing that document alone.
    /// The value tells the two removals apart.
    func removals(forAccount accountId: String,
                  conversationId: String,
                  documentId: String) -> Observable<Bool> {
        return documentsRemoved
            .filter {
                $0.accountId == accountId && $0.conversationId == conversationId
                    && $0.documentId == documentId
            }
            .map { $0.everywhere }
    }

    // MARK: - Documents waiting to be read

    /// How many of a conversation's documents changed without being opened
    /// since, starting with what it stands at now.
    func unreadDocumentCount(forAccount accountId: String,
                             conversationId: String) -> Observable<Int> {
        let conversation = CollaborationService.conversationKey(accountId, conversationId)
        return Observable.deferred { [weak self] in
            guard let self = self else { return Observable.empty() }
            return self.unreadCountSubject
                .filter { $0.conversation == conversation }
                .map { $0.count }
                .startWith(self.unreadCount(in: conversation))
        }
        .distinctUntilChanged()
    }

    /// The document has been opened, so it is no longer waiting to be read.
    func markDocumentRead(accountId: String, conversationId: String, documentId: String) {
        let conversation = CollaborationService.conversationKey(accountId, conversationId)
        clearUnread(in: conversation, documentId: documentId)
    }

    /// Everything the conversation was holding has been read.
    func markConversationDocumentsRead(accountId: String, conversationId: String) {
        let conversation = CollaborationService.conversationKey(accountId, conversationId)
        unreadLock.lock()
        let cleared = unreadDocumentIds.removeValue(forKey: conversation) != nil
        unreadLock.unlock()
        if cleared {
            unreadCountSubject.onNext((conversation: conversation, count: 0))
        }
    }

    private static func conversationKey(_ accountId: String, _ conversationId: String) -> String {
        return accountId + "|" + conversationId
    }

    private static func documentKey(_ accountId: String,
                                    _ conversationId: String,
                                    _ documentId: String) -> String {
        return conversationKey(accountId, conversationId) + "|" + documentId
    }

    private func unreadCount(in conversation: String) -> Int {
        unreadLock.lock()
        defer { unreadLock.unlock() }
        return unreadDocumentIds[conversation]?.count ?? 0
    }

    /// A document that changed is waiting to be read, unless it is open here.
    private func markUnread(accountId: String, conversationId: String, documentId: String) {
        let conversation = CollaborationService.conversationKey(accountId, conversationId)
        let document = CollaborationService.documentKey(accountId, conversationId, documentId)
        var count: Int?
        unreadLock.lock()
        if !openDocumentKeys.contains(document),
           unreadDocumentIds[conversation, default: []].insert(documentId).inserted {
            count = unreadDocumentIds[conversation]?.count
        }
        unreadLock.unlock()
        if let count = count {
            unreadCountSubject.onNext((conversation: conversation, count: count))
        }
    }

    private func clearUnread(in conversation: String, documentId: String) {
        var count: Int?
        unreadLock.lock()
        if unreadDocumentIds[conversation]?.remove(documentId) != nil {
            let remaining = unreadDocumentIds[conversation]?.count ?? 0
            if remaining == 0 {
                unreadDocumentIds.removeValue(forKey: conversation)
            }
            count = remaining
        }
        unreadLock.unlock()
        if let count = count {
            unreadCountSubject.onNext((conversation: conversation, count: count))
        }
    }

    private func setDocument(_ documentId: String,
                             openForAccount accountId: String,
                             conversationId: String,
                             isOpen: Bool) {
        let document = CollaborationService.documentKey(accountId, conversationId, documentId)
        unreadLock.lock()
        if isOpen {
            openDocumentKeys.insert(document)
        } else {
            openDocumentKeys.remove(document)
        }
        unreadLock.unlock()
    }

    // MARK: - Documents

    /**
     Announce a new document in a conversation, under the name it will go by:
     the one asked for, trimmed, or the default for one asked for without.

     - returns: its id, and the name it was created under.
     - throws: `CollaborationError.refused`, the daemon having declined.
     */
    func createDocument(accountId: String,
                        conversationId: String,
                        name: String,
                        mimeType: String = CollaborativeDocument.mimeRichText)
    -> Single<(id: String, name: String)> {
        let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let named = title.isEmpty ? L10n.Collab.untitled : title
        return fromDaemon { [adapter] in
            adapter.createDocument(forAccount: accountId,
                                   conversationId: conversationId,
                                   name: named,
                                   mimeType: mimeType)
        }
        .map { documentId in
            guard !documentId.isEmpty else { throw CollaborationError.refused }
            return (id: documentId, name: named)
        }
    }

    /**
     Start an editing session and get the whole document as one Y-CRDT update,
     to seed a fresh replica. Must be paired with `closeDocument`.
     */
    func openDocument(accountId: String,
                      conversationId: String,
                      documentId: String) -> Single<Data> {
        setDocument(documentId,
                    openForAccount: accountId,
                    conversationId: conversationId,
                    isOpen: true)
        markDocumentRead(accountId: accountId,
                         conversationId: conversationId,
                         documentId: documentId)
        return fromDaemon { [adapter] in
            adapter.openDocument(forAccount: accountId,
                                 conversationId: conversationId,
                                 documentId: documentId)
        }
        .do(onSuccess: { [weak self] state in
            if state.isEmpty {
                self?.setDocument(documentId,
                                  openForAccount: accountId,
                                  conversationId: conversationId,
                                  isOpen: false)
            }
        }, onError: { [weak self] _ in
            self?.setDocument(documentId,
                              openForAccount: accountId,
                              conversationId: conversationId,
                              isOpen: false)
        })
    }

    func closeDocument(accountId: String,
                       conversationId: String,
                       documentId: String) -> Completable {
        setDocument(documentId,
                    openForAccount: accountId,
                    conversationId: conversationId,
                    isOpen: false)
        return onDaemon { [adapter] in
            adapter.closeDocument(forAccount: accountId,
                                  conversationId: conversationId,
                                  documentId: documentId)
        }
    }

    /**
     Retire a document from the conversation, for every member and every device.

     Only its author can, and nothing brings it back. The answer says the removal
     was committed, not that the members applied it: `documentsRemoved` reports
     that, here as everywhere else.
     */
    func removeDocument(accountId: String,
                        conversationId: String,
                        documentId: String) -> Single<Bool> {
        return fromDaemon { [adapter] in
            adapter.removeDocument(forAccount: accountId,
                                   conversationId: conversationId,
                                   documentId: documentId)
        }
    }

    /**
     Drop a document from this device alone. Any member may, on any document.

     The document stays in the conversation and stays listed; opening it again
     fetches it back.
     */
    func removeDocumentLocally(accountId: String,
                               conversationId: String,
                               documentId: String) -> Single<Bool> {
        return fromDaemon { [adapter] in
            adapter.removeDocumentLocally(forAccount: accountId,
                                          conversationId: conversationId,
                                          documentId: documentId)
        }
    }

    /// Broadcast a local edit. The update is a Y-CRDT update, lib0 v1 encoding.
    func applyUpdate(accountId: String,
                     conversationId: String,
                     documentId: String,
                     update: Data) -> Completable {
        return onDaemon { [adapter] in
            adapter.applyUpdate(forAccount: accountId,
                                conversationId: conversationId,
                                documentId: documentId,
                                update: update)
        }
    }

    func documentState(accountId: String,
                       conversationId: String,
                       documentId: String) -> Single<Data> {
        return fromDaemon { [adapter] in
            adapter.documentState(forAccount: accountId,
                                  conversationId: conversationId,
                                  documentId: documentId)
        }
    }

    /**
     Publish this device's ephemeral state for a document. The daemon relays it
     untouched, so its shape is a matter between clients; the editors use
     `{"p":<caret>,"a":<anchor>}` in UTF-16 code units. An empty state withdraws
     this device's cursor.
     */
    func setAwareness(accountId: String,
                      conversationId: String,
                      documentId: String,
                      state: String) -> Completable {
        return onDaemon { [adapter] in
            adapter.setAwareness(forAccount: accountId,
                                 conversationId: conversationId,
                                 documentId: documentId,
                                 state: state)
        }
    }

    func setName(accountId: String,
                 conversationId: String,
                 documentId: String,
                 name: String) -> Completable {
        return onDaemon { [adapter] in
            adapter.setDocumentName(forAccount: accountId,
                                    conversationId: conversationId,
                                    documentId: documentId,
                                    name: name)
        }
    }

    func name(accountId: String, conversationId: String, documentId: String) -> Single<String> {
        return fromDaemon { [adapter] in
            adapter.documentName(forAccount: accountId,
                                 conversationId: conversationId,
                                 documentId: documentId)
        }
    }

    /// Every document announced in a conversation, newest first.
    func documents(accountId: String, conversationId: String) -> Single<[CollaborativeDocument]> {
        return fromDaemon { [adapter] in
            adapter.documents(forAccount: accountId, conversationId: conversationId)
                .compactMap { CollaborativeDocument(fromNative: $0) }
        }
    }

    /**
     Checkpoints of a document, newest first.
     - parameter max: 0 for the whole history.
     */
    func history(accountId: String,
                 conversationId: String,
                 documentId: String,
                 max: UInt32 = 0) -> Single<[CollaborativeVersion]> {
        return fromDaemon { [adapter] in
            adapter.documentHistory(forAccount: accountId,
                                    conversationId: conversationId,
                                    documentId: documentId,
                                    max: max)
                .compactMap { CollaborativeVersion(fromNative: $0) }
        }
    }

    /// The document as it stood at a checkpoint, as a Y-CRDT update.
    func stateAt(accountId: String,
                 conversationId: String,
                 documentId: String,
                 commitId: String) -> Single<Data> {
        return fromDaemon { [adapter] in
            adapter.documentState(forAccount: accountId,
                                  conversationId: conversationId,
                                  documentId: documentId,
                                  atCommit: commitId)
        }
    }

    // MARK: - Attachments

    /**
     Store bytes in the document's repository.
     - returns: the attachment id to reference from the document, empty on refusal.
     */
    func addAttachment(accountId: String,
                       conversationId: String,
                       documentId: String,
                       data: Data) -> Single<String> {
        return fromDaemon { [adapter] in
            adapter.addAttachment(forAccount: accountId,
                                  conversationId: conversationId,
                                  documentId: documentId,
                                  data: data)
        }
    }

    /**
     An attachment's bytes, empty while it has not reached this device yet;
     `attachments(forAccount:conversationId:documentId:)` then says when to ask
     again.
     */
    func attachment(accountId: String,
                    conversationId: String,
                    documentId: String,
                    attachmentId: String) -> Single<Data> {
        return fromDaemon { [adapter] in
            adapter.attachment(forAccount: accountId,
                               conversationId: conversationId,
                               documentId: documentId,
                               attachmentId: attachmentId)
        }
    }

    // MARK: - Helpers

    private func fromDaemon<T>(_ block: @escaping () -> T) -> Single<T> {
        return Single.deferred { Single.just(block()) }
            .subscribe(on: daemonScheduler)
    }

    private func onDaemon(_ block: @escaping () -> Void) -> Completable {
        return Completable.deferred {
            block()
            return Completable.empty()
        }
        .subscribe(on: daemonScheduler)
    }
}

// MARK: - CollaborationAdapterDelegate

extension CollaborationService: CollaborationAdapterDelegate {

    func documentUpdate(withAccountId accountId: String,
                        conversationId: String,
                        documentId: String,
                        update: Data) {
        markUnread(accountId: accountId, conversationId: conversationId, documentId: documentId)
        let change: CollaborativeDocumentChange = update.isEmpty ? .notification : .update(update)
        documentChangeSubject.onNext(DocumentChangeEvent(accountId: accountId,
                                                         conversationId: conversationId,
                                                         documentId: documentId,
                                                         change: change))
    }

    func awarenessChanged(withAccountId accountId: String,
                          conversationId: String,
                          documentId: String,
                          peerId: String,
                          clientId: UInt64,
                          state: String) {
        awarenessSubject.onNext(AwarenessUpdate(accountId: accountId,
                                                conversationId: conversationId,
                                                documentId: documentId,
                                                peerId: peerId,
                                                clientId: clientId,
                                                state: state))
    }

    func participantLeft(withAccountId accountId: String,
                         conversationId: String,
                         documentId: String,
                         peerId: String,
                         clientId: UInt64) {
        participantLeftSubject.onNext(ParticipantLeft(accountId: accountId,
                                                      conversationId: conversationId,
                                                      documentId: documentId,
                                                      peerId: peerId,
                                                      clientId: clientId))
    }

    func documentRenamed(withAccountId accountId: String,
                         conversationId: String,
                         documentId: String,
                         name: String) {
        renamedSubject.onNext(DocumentEvent(accountId: accountId,
                                            conversationId: conversationId,
                                            documentId: documentId,
                                            value: name))
    }

    func attachmentAdded(withAccountId accountId: String,
                         conversationId: String,
                         documentId: String,
                         attachmentId: String) {
        attachmentSubject.onNext(DocumentEvent(accountId: accountId,
                                               conversationId: conversationId,
                                               documentId: documentId,
                                               value: attachmentId))
    }

    func documentRemoved(withAccountId accountId: String,
                         conversationId: String,
                         documentId: String,
                         everywhere: Bool) {
        setDocument(documentId,
                    openForAccount: accountId,
                    conversationId: conversationId,
                    isOpen: false)
        markDocumentRead(accountId: accountId,
                         conversationId: conversationId,
                         documentId: documentId)
        removedSubject.onNext(DocumentRemoved(accountId: accountId,
                                              conversationId: conversationId,
                                              documentId: documentId,
                                              everywhere: everywhere))
    }
}
