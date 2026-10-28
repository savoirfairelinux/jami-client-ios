/*
 *  Copyright (C) 2023-2025 Savoir-faire Linux Inc.
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

struct AuthoredReaction: Identifiable {
    let id: String
    let emoji: String
}

class ReactionsRowViewModel: Identifiable, ObservableObject, NameObserver {
    let jamiId: String
    let messageId: String
    @Published var username: String = ""
    @Published var content = [String: String]()
    var disposeBag = DisposeBag()

    var infoState: PublishSubject<State>?

    init(reaction: MessageAction) {
        self.jamiId = reaction.author
        self.username = self.jamiId
        self.messageId = reaction.id
        self.content[reaction.id] = reaction.content
    }

    func addReaction(reaction: MessageAction) {
        if self.content.keys.contains(reaction.id) { return }
        self.content[reaction.id] = reaction.content
    }

    var reactions: [AuthoredReaction] {
        content
            .map { AuthoredReaction(id: $0.key, emoji: $0.value) }
            .sorted { $0.emoji != $1.emoji ? $0.emoji < $1.emoji : $0.id < $1.id }
    }

    func setInfoState(state: PublishSubject<State>) {
        self.infoState = state
        requestName(jamiId: jamiId)
    }
}

struct ReactionSegment: Identifiable, Equatable {
    let emoji: String
    let count: Int
    let includesLocalAccount: Bool

    var id: String { emoji }
}

struct ReactionColors {
    let background: Color
    let text: Color
}

class ReactionsContainerModel: ObservableObject {
    @Published var reactionsRow = [ReactionsRowViewModel]()
    @Published private(set) var segments = [ReactionSegment]()
    @Published private(set) var hiddenSegmentsCount = 0
    @Published private(set) var accessibilityValue = ""
    var message: MessageModel
    private let localJamiId: String
    private var infoState: PublishSubject<State>?
    var reactionsRowCreated = false

    private static let maxVisibleSegments = 4

    init(message: MessageModel, localJamiId: String) {
        self.message = message
        self.localJamiId = localJamiId
        self.updateSegments()
    }

    func setInfoState(state: PublishSubject<State>) {
        self.infoState = state
        reactionsRow.forEach { reaction in
            reaction.setInfoState(state: state)
        }
    }

    func onAppear() {
        if self.reactionsRowCreated { return }
        self.reactionsRowCreated.toggle()
        self.update()
    }

    func reactionsUpdated() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.updateSegments()
            if self.reactionsRowCreated {
                self.update()
            }
        }
    }

    private func updateSegments() {
        let reactionsByEmoji: [String: [MessageAction]] = Dictionary(grouping: message.reactions, by: \.content)
        let all: [ReactionSegment] = reactionsByEmoji
            .map { makeSegment(emoji: $0.key, reactions: $0.value) }
            .sorted(by: Self.isOrderedBefore)
        let visible = Self.visibleSegments(from: all)
        segments = visible
        hiddenSegmentsCount = all.count - visible.count
        accessibilityValue = Self.accessibilityValue(for: visible, hiddenCount: hiddenSegmentsCount)
    }

    private func makeSegment(emoji: String, reactions: [MessageAction]) -> ReactionSegment {
        let includesLocalAccount = reactions.contains { $0.author == localJamiId }
        return ReactionSegment(emoji: emoji, count: reactions.count, includesLocalAccount: includesLocalAccount)
    }

    private static func isOrderedBefore(_ lhs: ReactionSegment, _ rhs: ReactionSegment) -> Bool {
        if lhs.count != rhs.count {
            return lhs.count > rhs.count
        }
        return lhs.emoji < rhs.emoji
    }

    private static func visibleSegments(from sorted: [ReactionSegment]) -> [ReactionSegment] {
        let top = Array(sorted.prefix(maxVisibleSegments))
        guard let own = sorted.first(where: { $0.includesLocalAccount }), !top.contains(own) else { return top }
        return Array(sorted.prefix(maxVisibleSegments - 1)) + [own]
    }

    private static func accessibilityValue(for segments: [ReactionSegment], hiddenCount: Int) -> String {
        var parts: [String] = segments.map { segment in
            let summary = "\(segment.emoji) \(segment.count)"
            return segment.includesLocalAccount ? L10n.Accessibility.messageReactionIncludingYou(summary) : summary
        }
        if hiddenCount > 0 {
            parts.append(L10n.Accessibility.messageReactionsMore(hiddenCount))
        }
        return parts.joined(separator: ", ")
    }

    private func updateReaction(reaction: MessageAction) {
        if let existingReaction = getReaction(jamiId: reaction.author) {
            existingReaction.addReaction(reaction: reaction)
        } else {
            self.addReaction(reaction: reaction)
        }
    }

    private func addReaction(reaction: MessageAction) {
        let reactionRow = ReactionsRowViewModel(reaction: reaction)
        self.reactionsRow.append(reactionRow)
        if let state = self.infoState {
            reactionRow.setInfoState(state: state)
        }
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
}
