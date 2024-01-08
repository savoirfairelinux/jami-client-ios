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

class MessagePanelVM: ObservableObject {

    @Published var placeholder = L10n.Conversation.messagePlaceholder
    @Published var defaultEmoji = "👍"

    private let messagePanelState: PublishSubject<State>

    let disposeBag = DisposeBag()

    init(messagePanelState: PublishSubject<State>, bestName: Observable<String>) {
        self.messagePanelState = messagePanelState
        bestName
            .share()
            .asObservable()
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] bestName in
                guard let self = self else { return }
                let name = bestName.replacingOccurrences(of: "\0", with: "")
                guard !name.isEmpty else { return }
                let placeholder = L10n.Conversation.messagePlaceholder + name
                self.placeholder = placeholder
            })
            .disposed(by: self.disposeBag)
    }

    // MARK: MessagePanelState

    func sendMessage(text: String) {
        let textToSend = text.isEmpty ? defaultEmoji : text
        let trimmed = textToSend.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return
        }
        messagePanelState.onNext(MessagePanelState.sendMessage(content: trimmed))
    }

    func showMoreActions() {
        messagePanelState.onNext(MessagePanelState.showMoreActions)
    }

    func sendPhoto() {
        messagePanelState.onNext(MessagePanelState.sendPhoto)
    }

}
