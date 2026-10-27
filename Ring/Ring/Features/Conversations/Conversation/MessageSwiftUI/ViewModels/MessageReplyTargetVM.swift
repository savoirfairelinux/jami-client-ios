/*
 *  Copyright (C) 2023 - 2025 Savoir-faire Linux Inc.
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
import LinkPresentation

struct ReplyQuoteLine {
    let text: String
    let symbolName: String?
    let isDeleted: Bool
    let truncation: Text.TruncationMode
}

class MessageReplyTargetVM: ObservableObject {
    @Published private(set) var authorName = ""
    @Published private(set) var line: ReplyQuoteLine?
    @Published private(set) var thumbnail: UIImage?

    let alignment: HorizontalAlignment

    var target: MessageContentVM? {
        didSet {
            linkThumbnail = nil
            requestedLinkMetadata = nil
            guard let target = target else { return }
            targetSubscription = Publishers.CombineLatest(Publishers.CombineLatest4(target.$username, target.$messageDeleted, target.$content, target.$finalImage),
                                                          target.$metadata)
                .dropFirst()
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    self?.updateQuote()
                }
            updateQuote()
            target.updateUserName()
        }
    }
    private var targetSubscription: AnyCancellable?
    private var linkThumbnail: UIImage?
    private var requestedLinkMetadata: LPLinkMetadata?
    private static let linkThumbnailSize = CGSize(width: 240, height: 240)

    private let localJamiId: String
    private let contextMenuState: PublishSubject<State>

    init(contextMenuState: PublishSubject<State>, localJamiId: String, isIncoming: Bool) {
        self.localJamiId = localJamiId
        self.alignment = isIncoming ? .leading : .trailing
        self.contextMenuState = contextMenuState
    }

    var accessibilitySummary: String? {
        line.map { "\(authorName): \($0.text)" }
    }

    var canShowTarget: Bool {
        line.map { !$0.isDeleted } ?? false
    }

    private func updateQuote() {
        guard let target = target else { return }
        let authorId = target.message.authorId
        let name = authorId == localJamiId || authorId.isEmpty ? target.username.withYourselfSuffix() : target.username
        if authorName != name { authorName = name }
        thumbnail = Self.thumbnail(for: target) ?? (target.messageDeleted ? nil : linkThumbnail)
        line = Self.quoteLine(for: target, hasThumbnail: thumbnail != nil)
        loadLinkThumbnailIfNeeded(for: target)
    }

    private func loadLinkThumbnailIfNeeded(for target: MessageContentVM) {
        guard linkThumbnail == nil, !target.messageDeleted,
              let metadata = target.metadata, metadata !== requestedLinkMetadata,
              let provider = metadata.imageProvider else { return }
        requestedLinkMetadata = metadata
        provider.loadObject(ofClass: UIImage.self) { [weak self] image, _ in
            let thumbnail = (image as? UIImage)?.resizeIntoRectangle(of: MessageReplyTargetVM.linkThumbnailSize)
            DispatchQueue.main.async {
                guard let self = self, self.requestedLinkMetadata === metadata, let thumbnail = thumbnail else { return }
                self.linkThumbnail = thumbnail
                self.updateQuote()
            }
        }
    }

    private static func quoteLine(for target: MessageContentVM, hasThumbnail: Bool) -> ReplyQuoteLine {
        if target.messageDeleted {
            return ReplyQuoteLine(text: L10n.Conversation.lastMessageDeleted, symbolName: nil, isDeleted: true, truncation: .tail)
        }
        guard target.type == .fileTransfer else {
            let text = target.displayContent.replacingOccurrences(of: "\n", with: " ")
            return ReplyQuoteLine(text: text, symbolName: nil, isDeleted: false, truncation: .tail)
        }
        switch target.fileSymbolName {
        case "waveform":
            return ReplyQuoteLine(text: L10n.Conversation.replyQuoteAudio, symbolName: "waveform", isDeleted: false, truncation: .tail)
        case "video":
            return ReplyQuoteLine(text: L10n.Global.video, symbolName: "video", isDeleted: false, truncation: .tail)
        case "photo":
            return ReplyQuoteLine(text: L10n.Conversation.replyQuotePhoto, symbolName: hasThumbnail ? nil : "photo", isDeleted: false, truncation: .tail)
        default:
            return ReplyQuoteLine(text: target.fileName, symbolName: "doc", isDeleted: false, truncation: .middle)
        }
    }

    private static func thumbnail(for target: MessageContentVM) -> UIImage? {
        guard !target.messageDeleted, target.type == .fileTransfer,
              target.fileSymbolName == "photo" else { return nil }
        return target.finalImage
    }

    func onQuoteAppear() {
        target?.onQuoteAppear()
    }

    func scrollToReplyTarget() {
        if let target = target {
            self.contextMenuState.onNext(ContextMenu.scrollToReplyTarget(messageId: target.message.id))
        }
    }
}
