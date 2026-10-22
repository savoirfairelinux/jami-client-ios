/*
 *  Copyright (C) 2024 - 2025 Savoir-faire Linux Inc.
 *
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

struct OutgoingMessage {
    enum Content {
        case text(String)
        case data(displayName: String, data: Data)
        case file(path: String, displayName: String, readyAfter: TimeInterval)
    }

    let content: Content
    let parentId: String
}

struct DraftAttachment: Identifiable {
    enum Kind {
        case image
        case video
        case document
    }

    enum Status {
        case loading
        case ready(OutgoingMessage.Content)
        case failed
    }

    static let thumbnailSize: CGFloat = 64

    let id = UUID()
    let displayName: String
    let kind: Kind
    var status: Status = .loading
    var thumbnail: UIImage?

    var isLoading: Bool {
        if case .loading = status { return true }
        return false
    }
}

class MessagePanelVM: ObservableObject, MessageAppearanceProtocol {

    @Published var placeholder = L10n.Conversation.messagePlaceholder
    @Published var defaultEmoji = "👍"
    @Published var messageToReply: MessageContentVM?
    @Published var messageToEdit: MessageContentVM?
    @Published var isEdit: Bool = false
    @Published var avatarImage: UIImage?
    @Published var inReplyTo = ""
    @Published private(set) var attachments: [DraftAttachment] = []
    /// A collaborative document is a commit in the conversation's repository,
    /// so it can only be started where there is one.
    @Published var canWriteDocuments = false
    var styling: MessageStyling = MessageStyling()

    private let messagePanelState: PublishSubject<State>

    let disposeBag = DisposeBag()

    var isLoadingAttachments: Bool {
        attachments.contains(where: { $0.isLoading })
    }

    init(messagePanelState: PublishSubject<State>) {
        self.messagePanelState = messagePanelState
    }

    func subscribeBestName(bestName: Observable<String>) {
        bestName
            .share()
            .asObservable()
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] bestName in
                guard let self = self else { return }
                let name = bestName.replacingOccurrences(of: "\0", with: "")
                guard !name.isEmpty else { return }
                let placeholder = L10n.Conversation.messagePlaceholder + " " + name
                self.placeholder = placeholder
            })
            .disposed(by: self.disposeBag)
    }

    // MARK: MessagePanelState

    func sendDraft(text: String) {
        if messageToEdit != nil {
            editMessage(text: text)
            return
        }
        guard !isLoadingAttachments else { return }
        var contents: [OutgoingMessage.Content] = attachments.compactMap { attachment in
            guard case .ready(let content) = attachment.status else { return nil }
            return content
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            contents.append(.text(trimmed))
        } else if attachments.isEmpty {
            contents.append(.text(defaultEmoji))
        }
        attachments.removeAll()
        send(contents)
    }

    func send(_ content: OutgoingMessage.Content) {
        send([content])
    }

    private func send(_ contents: [OutgoingMessage.Content]) {
        guard !contents.isEmpty else { return }
        let parentId = messageToReply?.message.id ?? ""
        cancelReply()
        messagePanelState.onNext(MessagePanelState.send(messages: contents.map { OutgoingMessage(content: $0, parentId: parentId) }))
        UIAccessibility.post(notification: .announcement, argument: L10n.Accessibility.conversationMessageSent)
    }

    func editMessage(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return
        }
        guard let message = messageToEdit else { return }
        messagePanelState.onNext(MessagePanelState.editMessage(content: trimmed, messageId: message.message.id))
        cancelEdit()
    }

    func attach(displayName: String, kind: DraftAttachment.Kind, load: (@escaping (Data?) -> Void) -> Void) {
        guard messageToReply != nil else {
            load { [weak self] data in
                guard let data = data else { return }
                DispatchQueue.main.async {
                    let message = OutgoingMessage(content: .data(displayName: displayName, data: data), parentId: "")
                    self?.messagePanelState.onNext(MessagePanelState.send(messages: [message]))
                }
            }
            return
        }
        let attachment = DraftAttachment(displayName: displayName, kind: kind)
        attachments.append(attachment)
        load { [weak self] data in
            DispatchQueue.global(qos: .userInitiated).async {
                let thumbnail = data?.convertToImage(size: DraftAttachment.thumbnailSize)
                DispatchQueue.main.async {
                    guard let self = self,
                          let index = self.attachments.firstIndex(where: { $0.id == attachment.id }) else { return }
                    if let data = data {
                        self.attachments[index].thumbnail = thumbnail
                        self.attachments[index].status = .ready(.data(displayName: displayName, data: data))
                    } else {
                        self.attachments[index].status = .failed
                    }
                }
            }
        }
    }

    func removeAttachment(_ attachment: DraftAttachment) {
        attachments.removeAll(where: { $0.id == attachment.id })
    }

    func openGalery() {
        messagePanelState.onNext(MessagePanelState.openGalery)
    }

    func shareLocation() {
        messagePanelState.onNext(MessagePanelState.shareLocation)
    }

    func recordVideo() {
        messagePanelState.onNext(MessagePanelState.recordVido)
    }

    func sendFile() {
        messagePanelState.onNext(MessagePanelState.sendFile)
    }

    func sendPhoto() {
        messagePanelState.onNext(MessagePanelState.sendPhoto)
    }

    func newCollabDocument() {
        messagePanelState.onNext(MessagePanelState.newCollabDocument)
    }

    func configureReplyTo(message: MessageContentVM) {
        messageToReply = message
        isEdit = true
    }

    func configureEdit(message: MessageContentVM) {
        messageToEdit = message
        isEdit = true
    }

    func cancelReply() {
        messageToReply = nil
        isEdit = false
    }

    func cancelEdit() {
        messageToEdit = nil
        isEdit = false
    }

    func handleTyping(message: String) {
        if !message.isEmpty {
            messagePanelState.onNext(MessagePanelState.registerTypingIndicator(typingStatus: true))
        } else {
            messagePanelState.onNext(MessagePanelState.registerTypingIndicator(typingStatus: false))
        }
    }

    func updateUsername(name: String, jamiId: String) {
        guard let message = messageToReply, !name.isEmpty else { return }
        if message.message.authorId == jamiId {
            inReplyTo = name
        }
    }
}
