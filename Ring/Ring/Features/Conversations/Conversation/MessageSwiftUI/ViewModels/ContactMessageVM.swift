/*
 *  Copyright (C) 2022 Savoir-faire Linux Inc.
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
import SwiftUI
import RxSwift
import RxRelay

class ContactMessageVM: ObservableObject, MessageAppearanceProtocol, AvatarImageObserver, NameObserver {
    @Published var avatarImage: UIImage?
    @Published var content: String {
        didSet {
            self.observableContent.accept(content)
        }
    }
    @Published var borderColor: Color
    @Published var backgroundColor: Color
    var disposeBag = DisposeBag()
    let cornerRadius: CGFloat = 20
    let avatarSize: CGFloat = 15
    var inset: CGFloat
    var height: CGFloat
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
        self.backgroundColor = Color(UIColor.clear)
        self.inset = message.type == .initial ? 0 : 7
        self.height = message.type == .initial ? 25 : 45
        self.borderColor = message.type == .initial ? Color(UIColor.clear) : Color(UIColor.secondaryLabel)
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
            requestAvatar(jamiId: jamiId)
            requestName(jamiId: jamiId)
        }
    }

    func swarmColorUpdated(color: UIColor) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.borderColor = self.message.type != .initial ? Color(color) : Color(UIColor.clear)
        }
    }
}
