//
//  ReactionsRowView.swift
//  Ring
//
//  Created by kateryna on 2024-01-02.
//  Copyright © 2024 Savoir-faire Linux. All rights reserved.
//

import SwiftUI
import RxSwift

class ReactionsRowViewModel: Identifiable, ObservableObject {
    let jamiId: String
    @Published var image: Image = Image(uiImage: UIImage())
    @Published var name: String = ""
    var reasctions: String

    init(reaction: MessageReaction) {
        self.jamiId = reaction.author
        self.reasctions = reaction.content
        self.name = self.jamiId
    }

    func addReaction(reaction: String) {
        self.reasctions += " \(reaction)"
    }
}

class ReactionsContainerModel {
    var reactions = [ReactionsRowViewModel]()
    let message: MessageModel
    var infoState: PublishSubject<State>

    init(message: MessageModel, infoState: PublishSubject<State>) {
        self.message = message
        self.infoState = infoState
        self.createReactions()
    }

    func updateReaction(reaction: MessageReaction) {
        if let existingReaction = getReaction(jamiId: reaction.author) {
            existingReaction.addReaction(reaction: reaction.content)
        } else {
            self.reactions.append(ReactionsRowViewModel(reaction: reaction))
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
}

struct ReactionRowView: View {
    @ObservedObject var reaction: ReactionsRowViewModel

    var body: some View {
        HStack {
            reaction.image
                .resizable()
                .frame(width: 50, height: 50)
            Spacer()
                .frame(width: 20)
            Text(reaction.name)
                .font(.headline)
                .lineLimit(1)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
            Spacer()
            Text(reaction.reasctions)
                .font(.subheadline)
                .lineLimit(nil)
        }
        .padding(.horizontal, 20)
    }
}
