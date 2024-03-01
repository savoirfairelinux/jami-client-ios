/*
 *  Copyright (C) 2023-2024 Savoir-faire Linux Inc.
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

import SwiftUI
import RxSwift

class ReactionsRowViewModel: Identifiable, ObservableObject {
    let jamiId: String
    let messageId: String
    @Published var image: Image
    @Published var name: String = ""
    @Published var content = [String: String]()

    init(reaction: MessageAction) {
        self.jamiId = reaction.author
        self.name = self.jamiId
        self.messageId = reaction.id
        self.image = Image(uiImage: UIImage())
        self.content[reaction.id] = reaction.content
    }

    func addReaction(reaction: MessageAction) {
        if self.content.keys.contains(reaction.id) { return }
        self.content[reaction.id] = reaction.content
    }

    func toString() -> String {
        return content.values.joined(separator: " ")
    }
}

class ReactionsContainerModel: ObservableObject {
    @Published var reactionsRow = [ReactionsRowViewModel]()
    @Published var displayValue: String = ""
    let message: MessageModel
    private var infoState: PublishSubject<State>?
    var reactionsRowCreated = false

    init(message: MessageModel) {
        self.message = message
        self.updateDisplayValue()
    }

    func setInfoState(state: PublishSubject<State>) {
        self.infoState = state
    }

    func onAppear() {
        if self.reactionsRowCreated { return }
        self.reactionsRowCreated.toggle()
        self.update()
    }

    func updateUsername(name: String, jamiId: String) {
        guard let reaction = self.getReaction(jamiId: jamiId), !name.isEmpty else { return }
        reaction.name = name
    }

    func updateImage(image: UIImage, jamiId: String) {
        guard let reaction = self.getReaction(jamiId: jamiId) else { return }
        reaction.image = Image(uiImage: image)
    }

    func reactionsUpdated() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.updateDisplayValue()
            if self.reactionsRowCreated {
                self.update()
            }
        }
    }

    private func updateDisplayValue() {
        self.displayValue = self.toString()
    }

    private func updateReaction(reaction: MessageAction) {
        if let existingReaction = getReaction(jamiId: reaction.author) {
            existingReaction.addReaction(reaction: reaction)
        } else {
            self.addReaction(reaction: reaction)
        }
    }

    private func addReaction(reaction: MessageAction) {
        self.reactionsRow.append(ReactionsRowViewModel(reaction: reaction))
        self.infoState?.onNext(MessageInfo.updateDisplayname(jamiId: reaction.author))
        self.infoState?.onNext(MessageInfo.updateAvatar(jamiId: reaction.author))
    }

    private func update() {
        self.reactionsRow = [ReactionsRowViewModel]()
        self.message.reactions.forEach { reaction in
            self.updateReaction(reaction: reaction)
        }
    }

    private func getReaction(jamiId: String) -> ReactionsRowViewModel? {
        return self.reactionsRow.filter({ reaction in
            reaction.jamiId == jamiId
        }).first
    }

    private func toString() -> String {
        let reactions = self.message.reactions.map { reaction in
            reaction.content
        }

        return constructString(from: reactions, spaceBetweenCharacters: "  ", spaceBetweenCharAndCount: "")
    }

    private func constructString(from strings: [String], spaceBetweenCharacters: String, spaceBetweenCharAndCount: String) -> String {
        let charCounts = Dictionary(strings.map { ($0, 1) }, uniquingKeysWith: +)
        let result = charCounts
            .map { (str, count) in
                count > 1 ? "\(str)\(spaceBetweenCharAndCount)\(count)" : str
            }
            .joined(separator: spaceBetweenCharacters)

        return result
    }
}
