/*
 *  Copyright (C) 2026-2026 Savoir-faire Linux Inc.
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

import SwiftUI
import Photos
import UniformTypeIdentifiers

protocol MediaPreviewActionsDelegate: AnyObject {
    func deleteMessage()
}

protocol MediaPreviewConversationActions: AnyObject {
    var replyPanel: MessagePanelVM { get }
    var replyVoiceRecording: VoiceRecordingVM { get }

    func beginReply(to message: MessageContentVM)
    func react(to message: MessageContentVM, with emoji: String)
    func reactions(of message: MessageContentVM) -> ReactionsContainerModel?
    func showLatestMessage()
}

enum MediaPreviewSheet: Identifiable {
    case share(url: URL)
    case forward(injectionBag: InjectionBag, callback: ([String]) -> Void)

    var id: String {
        switch self {
        case .share: return "share"
        case .forward: return "forward"
        }
    }
}

enum MediaPreviewContent {
    case player(PlayerViewModel)
    case image(UIImage)
}

class MediaPreviewModel: ObservableObject {
    let content: MediaPreviewContent
    let canDelete: Bool
    let fileURL: URL?
    private weak var delegate: MediaPreviewActionsDelegate?
    private let photoSaver: PhotoLibrarySaving

    var injectionBag: InjectionBag?
    var forwardCallback: (([String]) -> Void)?
    @Published var title = ""
    var subtitle = ""
    weak var message: MessageContentVM?
    weak var conversationActions: MediaPreviewConversationActions?

    @Published var activeSheet: MediaPreviewSheet?
    @Published var saveError: String?
    @Published var saveSuccess: Bool = false
    @Published var needsPhotoPermission: Bool = false
    @Published var isReplying = false
    @Published var isReacting = false

    var isImagePreview: Bool {
        if case .image = content { return true }
        return false
    }

    var canSave: Bool {
        fileURL?.pathExtension.isImageExtension() == true
    }

    var canReply: Bool {
        guard message != nil, let actions = conversationActions else { return false }
        return actions.replyPanel.isComposerAvailable
    }

    var canReact: Bool {
        message != nil && conversationActions != nil
    }

    var reactions: ReactionsContainerModel? {
        guard let message = message else { return nil }
        return conversationActions?.reactions(of: message)
    }

    var ownReactions: Set<String> {
        Set(reactions?.segments.filter(\.includesLocalAccount).map(\.emoji) ?? [])
    }

    var reactionChoices: [String] {
        let preferred = ContextMenuVM.preferredReactions
        return preferred + ownReactions.subtracting(preferred).sorted()
    }

    init(content: MediaPreviewContent, delegate: MediaPreviewActionsDelegate, fileURL: URL? = nil, canDelete: Bool = false, photoSaver: PhotoLibrarySaving = SystemPhotoLibrarySaver()) {
        self.content = content
        self.delegate = delegate
        self.fileURL = fileURL
        self.canDelete = canDelete
        self.photoSaver = photoSaver
    }

    func share() {
        guard let url = fileURL else { return }
        activeSheet = .share(url: url)
    }

    func forward() {
        guard let bag = injectionBag, let callback = forwardCallback else { return }
        activeSheet = .forward(injectionBag: bag, callback: callback)
    }

    func save() {
        guard let url = fileURL else { return }
        if url.pathExtension.isImageExtension() {
            photoSaver.saveImageWithAuthCheck(
                url: url,
                onSuccess: { [weak self] in
                    DispatchQueue.main.async {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        self?.saveSuccess = true
                    }
                },
                onError: { [weak self] message in
                    DispatchQueue.main.async {
                        self?.saveError = message
                    }
                },
                onAccessDenied: { [weak self] in
                    DispatchQueue.main.async {
                        self?.needsPhotoPermission = true
                    }
                }
            )
        }
    }

    func copy() {
        guard let url = fileURL,
              let type = UTType(filenameExtension: url.pathExtension) else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            guard let data = try? Data(contentsOf: url) else { return }
            DispatchQueue.main.async {
                UIPasteboard.general.setData(data, forPasteboardType: type.identifier)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }

    func delete() { delegate?.deleteMessage() }

    func toggleReacting() {
        isReacting.toggle()
    }

    func react(_ emoji: String) {
        isReacting = false
        guard let message = message else { return }
        conversationActions?.react(to: message, with: emoji)
    }

    func beginReply() {
        guard let message = message, let actions = conversationActions else { return }
        isReacting = false
        actions.beginReply(to: message)
        isReplying = true
    }

    func cancelReply() {
        isReplying = false
        conversationActions?.replyVoiceRecording.cancel()
        conversationActions?.replyPanel.cancelReply()
    }

    func finishReply() {
        isReplying = false
    }

    func showLatestMessage() {
        conversationActions?.showLatestMessage()
    }
}
