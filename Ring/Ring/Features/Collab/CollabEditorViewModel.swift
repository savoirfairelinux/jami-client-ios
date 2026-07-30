/*
 *  Copyright (C) 2004-2026 Savoir-faire Linux Inc.
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

/**
 The application's side of a shared document.

 It owns everything the document *is*: what the daemon says about it, who else
 is in it, and what its history holds. It owns nothing about how the text is
 laid out or edited, which is the page's business and stays there.
 */
class CollabEditorViewModel {

    private let collaborationService: CollaborationService
    private let accountsService: AccountsService
    private let profileService: ProfilesService

    let accountId: String
    let conversationId: String
    let documentId: String

    private let disposeBag = DisposeBag()

    let documentName = BehaviorRelay<String>(value: "")

    /// The peer windows in the document, as `peerId/clientId`.
    private var present = Set<String>()
    let otherParticipants = BehaviorRelay<Int>(value: 0)

    /// A caret moves far more often than it needs to be reported.
    private let awarenessOut = PublishSubject<String>()

    private var peers = [String: CollabPeer]()

    /// Set once the daemon has handed the document over.
    private(set) var opened = false

    struct CollabPeer {
        let displayName: String
        let color: String
    }

    init(with injectionBag: InjectionBag,
         accountId: String,
         conversationId: String,
         documentId: String,
         name: String?) {
        self.collaborationService = injectionBag.collaborationService
        self.accountsService = injectionBag.accountService
        self.profileService = injectionBag.profileService
        self.accountId = accountId
        self.conversationId = conversationId
        self.documentId = documentId
        self.documentName.accept(name ?? "")

        // A caret that has stopped moving still has to be reported, so this
        // keeps the last position of every window rather than the first.
        self.awarenessOut
            .throttle(.milliseconds(CollabEditorViewModel.awarenessInterval),
                      latest: true,
                      scheduler: MainScheduler.instance)
            .distinctUntilChanged()
            .flatMapLatest { [weak self] state -> Completable in
                guard let self = self else { return Completable.empty() }
                return self.collaborationService
                    .setAwareness(accountId: self.accountId,
                                  conversationId: self.conversationId,
                                  documentId: self.documentId,
                                  state: state)
                    .catch { _ in Completable.empty() }
            }
            .subscribe()
            .disposed(by: self.disposeBag)
    }

    var title: String {
        let name = self.documentName.value
        return name.isEmpty ? L10n.Collab.untitled : name
    }

    var participantsDescription: String {
        // One person editing from two devices is two carets but one person.
        switch self.otherParticipants.value {
        case 0: return L10n.Collab.editingAlone
        case 1: return L10n.Collab.editingOneOther
        case let others: return L10n.Collab.editingOthers(others)
        }
    }

    // MARK: - Document

    /**
     The whole document, as one update to hand to the page.

     An empty answer is how the daemon says no: the document was never
     announced in this conversation, or it refused to open it. Showing an empty
     page instead would look like a document that simply never syncs.
     */
    func open() -> Single<Data> {
        return self.collaborationService
            .openDocument(accountId: self.accountId,
                          conversationId: self.conversationId,
                          documentId: self.documentId)
            .observe(on: MainScheduler.instance)
            .do(onSuccess: { [weak self] state in
                if !state.isEmpty { self?.opened = true }
            })
    }

    func close() {
        guard self.opened else { return }
        // Fire and forget: the daemon has to know this replica is gone so the
        // others stop showing its caret, but there is nothing to wait for.
        self.collaborationService
            .closeDocument(accountId: self.accountId,
                           conversationId: self.conversationId,
                           documentId: self.documentId)
            .subscribe()
            .disposed(by: self.disposeBag)
    }

    func send(update: Data) -> Completable {
        return self.collaborationService
            .applyUpdate(accountId: self.accountId,
                         conversationId: self.conversationId,
                         documentId: self.documentId,
                         update: update)
            .observe(on: MainScheduler.instance)
    }

    func report(awareness state: String) {
        guard self.opened else { return }
        self.awarenessOut.onNext(state)
    }

    var updates: Observable<Data> {
        return self.collaborationService
            .updates(forAccount: self.accountId,
                     conversationId: self.conversationId,
                     documentId: self.documentId)
            .observe(on: MainScheduler.instance)
    }

    /// A peer's caret, with the name and colour to write on it.
    var awareness: Observable<(AwarenessUpdate, CollabPeer)> {
        return self.collaborationService
            .awareness(forAccount: self.accountId,
                       conversationId: self.conversationId,
                       documentId: self.documentId)
            .observe(on: MainScheduler.instance)
            .compactMap { [weak self] update -> (AwarenessUpdate, CollabPeer)? in
                guard let self = self else { return nil }
                let peer = self.peer(for: update.peerId)
                self.present.insert(update.peerId + "/" + String(update.clientId))
                self.publishParticipants()
                return (update, peer)
            }
    }

    var departures: Observable<ParticipantLeft> {
        return self.collaborationService
            .departures(forAccount: self.accountId,
                        conversationId: self.conversationId,
                        documentId: self.documentId)
            .observe(on: MainScheduler.instance)
            .do(onNext: { [weak self] left in
                guard let self = self else { return }
                self.present.remove(left.peerId + "/" + String(left.clientId))
                self.publishParticipants()
            })
    }

    var renames: Observable<String> {
        return self.collaborationService.documentsRenamed
            .filter { [weak self] renamed in
                guard let self = self else { return false }
                return renamed.accountId == self.accountId
                    && renamed.conversationId == self.conversationId
                    && renamed.documentId == self.documentId
            }
            .map { $0.value }
            .observe(on: MainScheduler.instance)
            .do(onNext: { [weak self] name in self?.documentName.accept(name) })
    }

    /**
     A picture a peer put in the document reaches this device after the text
     that refers to it, so the page draws it before its bytes are here and is
     told there is nothing to draw. This says when to ask again.
     */
    var attachments: Observable<String> {
        return self.collaborationService
            .attachments(forAccount: self.accountId,
                         conversationId: self.conversationId,
                         documentId: self.documentId)
            .observe(on: MainScheduler.instance)
    }

    func refreshName() {
        self.collaborationService
            .name(accountId: self.accountId,
                  conversationId: self.conversationId,
                  documentId: self.documentId)
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] name in
                self?.documentName.accept(name)
            })
            .disposed(by: self.disposeBag)
    }

    func rename(to name: String) -> Completable {
        return self.collaborationService
            .setName(accountId: self.accountId,
                     conversationId: self.conversationId,
                     documentId: self.documentId,
                     name: name)
            .observe(on: MainScheduler.instance)
            .do(onCompleted: { [weak self] in self?.documentName.accept(name) })
    }

    // MARK: - History

    /// The saved versions, newest first, each with the label to show for it.
    func history() -> Single<[(version: CollaborativeVersion, label: String)]> {
        return self.collaborationService
            .history(accountId: self.accountId,
                     conversationId: self.conversationId,
                     documentId: self.documentId,
                     max: UInt32(CollabEditorViewModel.historyLimit))
            .flatMap { [weak self] versions -> Single<[(version: CollaborativeVersion, label: String)]> in
                guard let self = self else { return Single.just([]) }
                return self.names(for: versions).map { names in
                    versions.map { (version: $0, label: self.label(for: $0, names: names)) }
                }
            }
            .observe(on: MainScheduler.instance)
    }

    func state(at commitId: String) -> Single<Data> {
        return self.collaborationService
            .stateAt(accountId: self.accountId,
                     conversationId: self.conversationId,
                     documentId: self.documentId,
                     commitId: commitId)
            .observe(on: MainScheduler.instance)
    }

    func describe(_ version: CollaborativeVersion) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(version.timestamp))
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    /**
     The name to show for every author in `versions`.

     A checkpoint is written by whoever made the changes it holds, so the
     history of a shared document is a history of several people. Without a
     name against each entry it reads as one person's, which it is not.

     A profile that does not arrive must not hold the list back: the identifier
     is a poor label but a timely one.
     */
    private func names(for versions: [CollaborativeVersion]) -> Single<[String: String]> {
        let authors = Array(Set(versions.map { $0.author }.filter { !$0.isEmpty }))
        guard !authors.isEmpty else { return Single.just([:]) }
        let mine = self.accountsService.getAccount(fromAccountId: self.accountId)?.jamiId
        let lookups: [Observable<(String, String)>] = authors.map { author in
            if author == mine {
                return Observable.just((author, L10n.Account.me))
            }
            return self.profileService
                .getProfile(uri: author, createIfNotexists: false, accountId: self.accountId)
                .map { profile in profile.alias ?? "" }
                .take(1)
                .timeout(.seconds(CollabEditorViewModel.profileWait),
                         other: Observable.just(""),
                         scheduler: MainScheduler.instance)
                .map { name in
                    (author, name.isEmpty ? CollabEditorViewModel.shortId(author) : name)
                }
        }
        return Observable.zip(lookups)
            .take(1)
            .asSingle()
            .map { pairs in Dictionary(pairs, uniquingKeysWith: { first, _ in first }) }
    }

    private func label(for version: CollaborativeVersion, names: [String: String]) -> String {
        let time = self.describe(version)
        guard let who = names[version.author] else { return time }
        if version.deltas > 0 {
            return L10n.Collab.versionDeltas(who, time, Int(version.deltas))
        }
        return L10n.Collab.versionBy(who, time)
    }

    // MARK: - Attachments

    func addAttachment(_ data: Data) -> Single<String> {
        return self.collaborationService
            .addAttachment(accountId: self.accountId,
                           conversationId: self.conversationId,
                           documentId: self.documentId,
                           data: data)
            .observe(on: MainScheduler.instance)
    }

    /// Called from a web view thread that has nowhere to put a later answer.
    func attachment(_ attachmentId: String) -> Single<Data> {
        return self.collaborationService
            .attachment(accountId: self.accountId,
                        conversationId: self.conversationId,
                        documentId: self.documentId,
                        attachmentId: attachmentId)
    }

    // MARK: - Peers

    /**
     The name and colour to write on a peer's caret.

     A profile is loaded rather than read, so a caret starts out labelled with
     a fragment of its owner's identifier and takes their name when it arrives.
     Carets move constantly, so the next awareness event carries the corrected
     label; nothing has to be redrawn on purpose.
     */
    private func peer(for peerId: String) -> CollabPeer {
        if let known = self.peers[peerId] { return known }
        let color = CollabEditorViewModel
            .cursorColors[self.peers.count % CollabEditorViewModel.cursorColors.count]
        let peer = CollabPeer(displayName: CollabEditorViewModel.shortId(peerId), color: color)
        self.peers[peerId] = peer
        self.profileService
            .getProfile(uri: peerId, createIfNotexists: false, accountId: self.accountId)
            .take(1)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] profile in
                guard let self = self, let name = profile.alias, !name.isEmpty else { return }
                self.peers[peerId] = CollabPeer(displayName: name, color: color)
            })
            .disposed(by: self.disposeBag)
        return peer
    }

    private func publishParticipants() {
        let others = Set(self.present.map { $0.components(separatedBy: "/").first ?? $0 })
        self.otherParticipants.accept(others.count)
    }

    private static func shortId(_ peerId: String) -> String {
        return peerId.count > 8 ? String(peerId.prefix(8)) : peerId
    }

    // MARK: - Constants

    private static let awarenessInterval = 200
    private static let historyLimit = 50
    /// How long a name is worth waiting for before showing an id.
    private static let profileWait = 2

    /// The daemon's own ceiling for one attachment.
    static let maxAttachmentBytes = 16 * 1024 * 1024

    private static let cursorColors = [
        "#E53935", "#1E88E5", "#43A047", "#FB8C00", "#8E24AA", "#00ACC1", "#F4511E"
    ]
}
