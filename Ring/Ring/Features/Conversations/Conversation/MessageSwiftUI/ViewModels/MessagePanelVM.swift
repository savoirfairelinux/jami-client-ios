/*
 *  Copyright (C) 2024 Savoir-faire Linux Inc.
 *
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
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

class MessagePanelVM: ObservableObject, MessageAppearanceProtocol {

    @Published var placeholder = L10n.Conversation.messagePlaceholder
    @Published var defaultEmoji = "👍"
    @Published var messageToReply: MessageContentVM?
    @Published var messageToEdit: MessageContentVM?
    @Published var isEdit: Bool = false
    @Published var avatarImage: UIImage?
    @Published var inReplyTo = ""
    var styling: MessageStyling = MessageStyling()

    private let messagePanelState: PublishSubject<State>

    let disposeBag = DisposeBag()

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

    func sendMessage(text: String) {
        if messageToEdit != nil {
            editMessage(text: text)
        } else {
            let textToSend = text.isEmpty ? defaultEmoji : text
            let trimmed = textToSend.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                return
            }
            let parentId = self.messageToReply?.message.id ?? ""
            messagePanelState.onNext(MessagePanelState.sendMessage(content: trimmed, parentId: parentId))
        }
    }

    func editMessage(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return
        }
        guard let message = messageToEdit else { return }
        messagePanelState.onNext(MessagePanelState.editMessage(content: trimmed, messageId: message.message.id))

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

    func recordAudio() {
        messagePanelState.onNext(MessagePanelState.recordAudio)
    }

    func sendFile() {
        messagePanelState.onNext(MessagePanelState.sendFile)
    }

    func sendPhoto() {
        messagePanelState.onNext(MessagePanelState.sendPhoto)
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

    func updateUsername(name: String, jamiId: String) {
        guard let message = messageToReply, !name.isEmpty else { return }
        if message.message.authorId == jamiId {
            inReplyTo = name
        }
    }
}
