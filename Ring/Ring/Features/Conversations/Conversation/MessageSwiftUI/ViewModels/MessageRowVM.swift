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
    @Published var timeString: String = ""
    @Published var topSpace: CGFloat = 0
    @Published var bottomSpace: CGFloat = 0
    @Published var leadingSpace: CGFloat = 0
    @Published var readBorderColor: Color
    @Published var showSentIndicator: Bool = false
    @Published var showReciveIndicator: Bool = false
    @Published var shouldDisplayAavatar = false
    var styling: MessageStyling = MessageStyling()
    var incoming: Bool
    var infoState: PublishSubject<State>?
    var centeredMessage: Bool

    var message: MessageModel
    var disposeBag = DisposeBag()
    var readDisposeBag = DisposeBag()

    var shouldShowTimeString = false {
        didSet {
            self.timeString = self.shouldShowTimeString ? self.message.receivedDate.getTimeLabelString() : ""
        }
    }

    var sequencing: MessageSequencing = .unknown {
        didSet {
            topSpace = (sequencing == .singleMessage || sequencing == .firstOfSequence) ? 2 : 0
            bottomSpace = (sequencing == .singleMessage || sequencing == .lastOfSequence) ? 2 : 0
        }
    }

    init(message: MessageModel) {
        self.message = message
        self.incoming = message.incoming
        self.centeredMessage = message.type.isContact || message.type == .initial
        self.readBorderColor = Color(UIColor.systemBackground)
        self.timeString = self.message.receivedDate.getTimeLabelString()
        self.updateMessageStatus()
    }

    func setInfoState(state: PublishSubject<State>) {
        self.infoState = state
        self.requestReadStatus(messageId: self.message.id)
    }

    func setSequencing(sequencing: MessageSequencing) {
        if self.sequencing != sequencing {
            DispatchQueue.main.async {[weak self] in
                guard let self = self else { return }
                self.sequencing = sequencing
            }
        }
    }

    func shouldDisplayContactInfoForConversation(state: Bool) {
        leadingSpace = state ? 50 : 12
    }

    func updateMessageStatus() {
        DispatchQueue.main.async {[weak self] in
            guard let self = self else { return }
            self.showSentIndicator = self.message.isSending()
        }
    }

    func displayLastSent(state: Bool) {
        DispatchQueue.main.async {[weak self] in
            guard let self = self else { return }
            self.showReciveIndicator = state
        }
    }
}
