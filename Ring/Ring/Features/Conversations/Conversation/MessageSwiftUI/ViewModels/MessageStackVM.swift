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

class MessageStackVM: MessageAppearanceProtocol, NameObserver {
    @Published var username = ""
    var horizontalAllignment: HorizontalAlignment {
        self.message.incoming ? HorizontalAlignment.leading : HorizontalAlignment.trailing
    }
    var alignment: Alignment {
        self.message.incoming ? Alignment.leading : Alignment.trailing
    }
    var message: MessageModel

    private var infoState: PublishSubject<State>?

    var styling: MessageStyling = MessageStyling()

    var disposeBag = DisposeBag()

    @Published var shouldDisplayName = false {
        didSet {
            let jamiId = message.uri.isEmpty ? message.authorId : message.uri
            if shouldDisplayName, let infoState = self.infoState {
                infoState.onNext(MessageInfo.updateDisplayname(jamiId: jamiId, message: self))
            } else {
                self.username = ""
            }
        }
    }

    init(message: MessageModel) {
        self.message = message
    }

    func setInfoState(state: PublishSubject<State>) {
        self.infoState = state
    }

}
