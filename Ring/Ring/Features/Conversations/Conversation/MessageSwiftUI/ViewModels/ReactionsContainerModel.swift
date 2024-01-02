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
    @Published var reactions = [String: String]()

    init(reaction: MessageReaction) {
        self.jamiId = reaction.author
        self.name = self.jamiId
        self.messageId = reaction.id
        self.image = Image(uiImage: UIImage())
        self.reactions[reaction.id] = reaction.content
    }

    func addReaction(reaction: MessageReaction) {
        if self.reactions.keys.contains(reaction.id) { return }
        self.reactions[reaction.id] = reaction.content
    }

    func getReactionsString() -> String {
        return reactions.values.joined(separator: " ")
    }
}

class ReactionsContainerModel: ObservableObject {
    @Published var reactions = [ReactionsRowViewModel]()
    let message: MessageModel
    let infoState: PublishSubject<State>
    var reactionCreated = false
    @Published var reactionsString: String = ""

    init(message: MessageModel, infoState: PublishSubject<State>) {
        self.message = message
        self.infoState = infoState
        self.reactionsString = getReactionsString()
    }

    func onAppear() {
        if self.reactionCreated { return }
        self.reactionCreated = true
        self.createReactions()
    }

    func updateReaction(reaction: MessageReaction) {
        if let existingReaction = getReaction(jamiId: reaction.author) {
            existingReaction.addReaction(reaction: reaction)
        } else {
            self.addReaction(reaction: reaction)
        }
    }

    func addReaction(reaction: MessageReaction) {
        self.reactions.append(ReactionsRowViewModel(reaction: reaction))
        self.infoState.onNext(MessageInfo.updateDisplayname(jamiId: reaction.author))
        self.infoState.onNext(MessageInfo.updateAvatar(jamiId: reaction.author))
    }

    func createReactions() {
        if self.message.reactions.isEmpty {
            return
        }
        self.message.reactions.forEach { reaction in
            self.updateReaction(reaction: reaction)
        }
    }

    func getReaction(jamiId: String) -> ReactionsRowViewModel? {
        return self.reactions.filter({ reaction in
            reaction.jamiId == jamiId
        }).first
    }

    func updateUsername(name: String, jamiId: String) {
        guard let reaction = self.getReaction(jamiId: jamiId), !name.isEmpty else { return }
        reaction.name = name
    }

    func updateImage(image: UIImage, jamiId: String) {
        guard let reaction = self.getReaction(jamiId: jamiId) else { return }
        reaction.image = Image(uiImage: image)
    }

    func getReactions() -> [ReactionsRowViewModel]? {
        return self.reactions.isEmpty ? nil : self.reactions
    }

    func getReactionsString() -> String {
        let reactions = self.message.reactions.map { reaction in
            reaction.content
        }

        return constructString(from: reactions, spaceBetweenCharacters: "  ", spaceBetweenCharAndCount: "")
    }

    func constructString(from strings: [String], spaceBetweenCharacters: String, spaceBetweenCharAndCount: String) -> String {
        var charCounts = [String: Int]()
        var result = ""

        for str in strings {
            charCounts[str, default: 0] += 1
        }

        for (str, count) in charCounts {
            if count > 1 {
                result += "\(str)\(spaceBetweenCharAndCount)\(count)\(spaceBetweenCharacters)"
            } else {
                result += "\(str)\(spaceBetweenCharacters)"
            }
        }

        result = String(result.dropLast(spaceBetweenCharacters.count))
        return result
    }

    func reactionsUpdated() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.reactions = [ReactionsRowViewModel]()
            self.reactionsString = getReactionsString()
            if reactionCreated {
                self.createReactions()
            }
        }
    }
}
