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

class ContactMessageVM: ObservableObject {
    @Published var avatarImage: UIImage?
    @Published var content: String
    var borderColor: Color
    var backgroundColor: Color
    var textColor: Color
    let cornerRadius: CGFloat = 15
    var inset: CGFloat
    var textFont: Font = .body

    var message: MessageModel
    var username = "" {
        didSet {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.content = self.username + " " + self.message.content
            }
        }
    }
    var infoState: PublishSubject<State>

    init(message: MessageModel, infoState: PublishSubject<State>) {
        self.message = message
        self.infoState = infoState
        self.textColor = Color(UIColor.label)
        self.backgroundColor = Color(UIColor.clear)
        self.inset = message.type == .initial ? 0 : 15
        self.borderColor = message.type == .initial ? Color(UIColor.clear) : Color(UIColor.secondaryLabel)
        self.content = message.content
        if message.type == .contact && message.incoming {
            self.infoState.onNext(MessageInfo.updateAvatar(jamiId: message.uri))
            self.infoState.onNext(MessageInfo.updateDisplayname(jamiId: message.uri))
        }
    }
}
