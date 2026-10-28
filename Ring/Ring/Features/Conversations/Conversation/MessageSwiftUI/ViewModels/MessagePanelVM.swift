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
import SwiftUI
import RxSwift
import Combine

struct OutgoingMessage {
    enum Content {
        case text(String)
        case data(displayName: String, data: Data)
        case file(path: String, displayName: String, readyAfter: TimeInterval = 0)
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

    var readyContent: OutgoingMessage.Content? {
        if case .ready(let content) = status { return content }
        return nil
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
    @Published private(set) var quote: MessageReplyTargetVM?
    @Published private(set) var quoteAccent: Color = .clear
    @Published private(set) var attachments: [DraftAttachment] = []
    /// A collaborative document is a commit in the conversation's repository,
    /// so it can only be started where there is one.
    @Published var canWriteDocuments = false
    var styling: MessageStyling = MessageStyling()

    private let messagePanelState: PublishSubject<State>
    private var replyNameSubscription: AnyCancellable?

    let disposeBag = DisposeBag()

    var isLoadingAttachments: Bool {
        attachments.contains(where: { $0.isLoading })
    }

    init(messagePanelState: PublishSubject<State>) {
        self.messagePanelState = messagePanelState
    }

    deinit {
        attachments.compactMap(\.readyContent).forEach(Self.discardFile)
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

    func isDraftEmpty(text: String) -> Bool {
        text.isEmpty && attachments.isEmpty
    }

    func sendDraft(text: String) {
        if messageToEdit != nil {
            editMessage(text: text)
            return
        }
        guard !isLoadingAttachments else { return }
        let contents = draftContents(text: text)
        attachments.removeAll()
        send(contents)
    }

    private func draftContents(text: String) -> [OutgoingMessage.Content] {
        if isDraftEmpty(text: text) {
            return [.text(defaultEmoji)]
        }
        let files = attachments.compactMap(\.readyContent)
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? files : files + [.text(trimmed)]
    }

    func send(_ content: OutgoingMessage.Content) {
        send([content])
    }

    private func send(_ contents: [OutgoingMessage.Content]) {
        guard !contents.isEmpty else { return }
        emit(contents, parentId: takeReplyParentId())
    }

    typealias ContentLoader = (@escaping (OutgoingMessage.Content?) -> Void) -> Void

    /// Sends the loaded media in the order given.
    func send(media loaders: [ContentLoader]) {
        guard !loaders.isEmpty else { return }
        let parentId = messageToReply?.message.id ?? ""
        var loaded = [OutgoingMessage.Content?](repeating: nil, count: loaders.count)
        let group = DispatchGroup()
        for (index, load) in loaders.enumerated() {
            group.enter()
            load { content in
                DispatchQueue.main.async {
                    loaded[index] = content
                    group.leave()
                }
            }
        }
        group.notify(queue: .main) { [weak self] in
            let files = loaded.compactMap { $0 }
            guard let self = self else {
                files.forEach(Self.discardFile)
                return
            }
            if files.count < loaders.count {
                self.messagePanelState.onNext(MessagePanelState.attachmentFailed)
            }
            guard !files.isEmpty else { return }
            if !parentId.isEmpty && self.messageToReply?.message.id == parentId {
                self.endReply()
            }
            self.emit(files, parentId: parentId)
        }
    }

    private func takeReplyParentId() -> String {
        guard let message = messageToReply else { return "" }
        endReply()
        return message.message.id
    }

    private func emit(_ contents: [OutgoingMessage.Content], parentId: String) {
        messagePanelState.onNext(MessagePanelState.send(messages: contents.map { OutgoingMessage(content: $0, parentId: parentId) }))
        UIAccessibility.post(notification: .announcement, argument: L10n.Accessibility.conversationMessageSent)
    }

    func editMessage(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, let message = messageToEdit {
            messagePanelState.onNext(MessagePanelState.editMessage(content: trimmed, messageId: message.message.id))
        }
        cancelEdit()
    }

    func attach(displayName: String, kind: DraftAttachment.Kind, load: (@escaping (OutgoingMessage.Content?) -> Void) -> Void) {
        guard messageToReply != nil else {
            load { [weak self] content in
                DispatchQueue.main.async {
                    guard let self = self else {
                        content.map(Self.discardFile)
                        return
                    }
                    guard let content = content else {
                        self.messagePanelState.onNext(MessagePanelState.attachmentFailed)
                        return
                    }
                    self.messagePanelState.onNext(MessagePanelState.send(messages: [OutgoingMessage(content: content, parentId: "")]))
                }
            }
            return
        }
        let attachment = DraftAttachment(displayName: displayName, kind: kind)
        attachments.append(attachment)
        load { [weak self] content in
            DispatchQueue.global(qos: .userInitiated).async {
                let thumbnail = content.flatMap { Self.thumbnail(for: $0, kind: kind) }
                DispatchQueue.main.async {
                    guard let self = self,
                          let index = self.attachments.firstIndex(where: { $0.id == attachment.id }) else {
                        content.map(Self.discardFile)
                        return
                    }
                    if let content = content {
                        self.attachments[index].thumbnail = thumbnail
                        self.attachments[index].status = .ready(content)
                    } else {
                        self.attachments[index].status = .failed
                    }
                }
            }
        }
    }

    func removeAttachment(_ attachment: DraftAttachment) {
        guard let index = attachments.firstIndex(where: { $0.id == attachment.id }) else { return }
        attachments.remove(at: index).readyContent.map(Self.discardFile)
    }

    private static func thumbnail(for content: OutgoingMessage.Content, kind: DraftAttachment.Kind) -> UIImage? {
        switch content {
        case .data(_, let data):
            return data.convertToImage(size: DraftAttachment.thumbnailSize)
        case .file(let path, _, _):
            guard kind == .image else { return nil }
            return UIImage.getImagefromURL(fileURL: URL(fileURLWithPath: path), maxSize: DraftAttachment.thumbnailSize * UIScreen.main.scale)
        case .text:
            return nil
        }
    }

    private static func discardFile(of content: OutgoingMessage.Content) {
        if case .file(let path, _, _) = content {
            try? FileManager.default.removeItem(atPath: path)
        }
    }

    func openGalery() {
        messagePanelState.onNext(MessagePanelState.openGalery)
    }

    func shareLocation() {
        discardDraftAttachments()
        messagePanelState.onNext(MessagePanelState.shareLocation)
    }

    func recordVideo() {
        discardDraftAttachments()
        messagePanelState.onNext(MessagePanelState.recordVido)
    }

    func sendFile() {
        messagePanelState.onNext(MessagePanelState.sendFile)
    }

    func sendPhoto() {
        messagePanelState.onNext(MessagePanelState.sendPhoto)
    }

    func newCollabDocument() {
        discardDraftAttachments()
        messagePanelState.onNext(MessagePanelState.newCollabDocument)
    }

    func configureReplyTo(message: MessageContentVM, quote: MessageReplyTargetVM) {
        cancelEdit()
        if messageToReply?.message.id != message.message.id {
            discardDraftAttachments()
            inReplyTo = ""
        }
        messageToReply = message
        replyNameSubscription = message.$username
            .removeDuplicates()
            .sink { [weak self] name in
                guard let self = self, self.inReplyTo != name else { return }
                self.inReplyTo = name
            }
        message.updateUserName()
        show(quote: quote, of: message)
        isEdit = true
    }

    func configureEdit(message: MessageContentVM, quote: MessageReplyTargetVM) {
        cancelReply()
        messageToEdit = message
        show(quote: quote, of: message)
        isEdit = true
    }

    private func show(quote: MessageReplyTargetVM, of message: MessageContentVM) {
        quoteAccent = Color(UIColor.MessageBubblePalette.palette(for: message.preferencesColor).unbubbledReplyQuoteAccent)
        self.quote = quote
    }

    func cancelReply() {
        discardDraftAttachments()
        endReply()
    }

    private func endReply() {
        replyNameSubscription = nil
        inReplyTo = ""
        messageToReply = nil
        quote = nil
        isEdit = false
    }

    func discardDraftAttachments() {
        guard !attachments.isEmpty else { return }
        attachments.compactMap(\.readyContent).forEach(Self.discardFile)
        attachments.removeAll()
        UIAccessibility.post(notification: .announcement, argument: L10n.Accessibility.draftAttachmentsDiscarded)
    }

    func cancelEdit() {
        messageToEdit = nil
        quote = nil
        isEdit = false
    }

    func handleTyping(message: String) {
        if !message.isEmpty {
            messagePanelState.onNext(MessagePanelState.registerTypingIndicator(typingStatus: true))
        } else {
            messagePanelState.onNext(MessagePanelState.registerTypingIndicator(typingStatus: false))
        }
    }
}
