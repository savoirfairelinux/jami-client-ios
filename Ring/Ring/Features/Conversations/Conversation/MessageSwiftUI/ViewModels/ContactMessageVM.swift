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
import SwiftUI
import RxSwift
import RxRelay

class ContactMessageVM: ObservableObject, MessageAppearanceProtocol, NameObserver {

    @Published var needAvatar: Bool = false
    @Published var content: String {
        didSet {
            self.observableContent.accept(content)
        }
    }
    var disposeBag = DisposeBag()
    var inset: CGFloat
    var styling: MessageStyling = MessageStyling()
    var observableContent = BehaviorRelay<String>(value: "")

    var message: MessageModel
    var username = "" {
        didSet {
            let jamiId = message.uri.isEmpty ? message.authorId : message.uri
            let name = self.username.isEmpty ? jamiId : self.username
            self.content = self.message.getContactInteractionString(name: name) ?? ""
        }
    }
    var infoState: PublishSubject<State>?

    init(message: MessageModel) {
        self.message = message
        self.inset = message.type == .initial ? 0 : 7
        self.content = message.content
        self.observableContent.accept(message.content)
        if message.type != .initial {
            self.styling.textFont = self.styling.secondaryFont
            self.styling.textColor = self.styling.defaultSecondaryTextColor
        }
    }

    func setInfoState(state: PublishSubject<State>) {
        self.infoState = state
        if message.type.isContact && message.incoming {

            let jamiId = message.uri.isEmpty ? message.authorId : message.uri
            needAvatar = true
            requestName(jamiId: jamiId)
        }
    }
}
