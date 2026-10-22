/*
 *  Copyright (C) 2022 - 2025 Savoir-faire Linux Inc.
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
import SwiftUI

class MessageRowVM: ObservableObject, MessageAppearanceProtocol, MessageReadObserver {
    @Published var readIds: [String]?
    @Published var daySeparatorText: String?
    @Published var eventGroupTimeText: String?
    @Published var eventGroupAccessibilityText: String?
    @Published var topSpace: CGFloat = 0
    @Published var bottomSpace: CGFloat = 0
    @Published var reservesAvatarSlot = false
    @Published var readBorderColor: Color
    @Published var showSentIndicator: Bool = false
    @Published var showReciveIndicator: Bool = false
    @Published var shouldDisplayAavatar = false
    var styling: MessageStyling = MessageStyling()
    var incoming: Bool
    var infoState: PublishSubject<State>?
    var centeredMessage: Bool

    private struct RowSpacing {
        let groupEdge: CGFloat
        let inGroup: CGFloat

        static let bubble = RowSpacing(groupEdge: 3, inGroup: 1)
        static let event = RowSpacing(groupEdge: 10, inGroup: 4)
    }

    var message: MessageModel
    var disposeBag = DisposeBag()
    var readDisposeBag = DisposeBag()

    var startsNewDay = false {
        didSet {
            refreshDaySeparator()
        }
    }

    var sequencing: MessageSequencing = .unknown {
        didSet {
            let spacing = centeredMessage ? RowSpacing.event : RowSpacing.bubble
            topSpace = (sequencing == .singleMessage || sequencing == .firstOfSequence) ? spacing.groupEdge : spacing.inGroup
            bottomSpace = (sequencing == .singleMessage || sequencing == .lastOfSequence) ? spacing.groupEdge : spacing.inGroup
            refreshEventGroupTime()
        }
    }

    init(message: MessageModel) {
        self.message = message
        self.incoming = message.incoming
        self.centeredMessage = message.type.isCentered
        self.readBorderColor = Color(UIColor.systemBackground)
        self.updateMessageStatus()
    }

    func refreshDates() {
        refreshDaySeparator()
        refreshEventGroupTime()
    }

    private func refreshEventGroupTime() {
        let closesEventGroup = message.type.isCentered
            && (sequencing == .singleMessage || sequencing == .lastOfSequence)
        let timeText = closesEventGroup ? message.receivedDate.messageTimeString() : nil
        let accessibilityText = closesEventGroup ? message.receivedDate.messageFullDateString() : nil
        if timeText != eventGroupTimeText {
            eventGroupTimeText = timeText
        }
        if accessibilityText != eventGroupAccessibilityText {
            eventGroupAccessibilityText = accessibilityText
        }
    }

    private func refreshDaySeparator() {
        let text = startsNewDay ? message.receivedDate.conversationDayLabel() : nil
        if text != daySeparatorText {
            daySeparatorText = text
        }
    }

    func setInfoState(state: PublishSubject<State>) {
        self.infoState = state
        self.requestReadStatus(messageId: self.message.id)
    }

    func setSequencing(sequencing: MessageSequencing) {
        if self.sequencing != sequencing {
            self.sequencing = sequencing
        }
    }

    func shouldDisplayContactInfoForConversation(state: Bool) {
        reservesAvatarSlot = state
    }

    func updateMessageStatus() {
        self.showSentIndicator = self.message.isSending()
    }

    func displayLastSent(state: Bool) {
        self.showReciveIndicator = state
    }
}
