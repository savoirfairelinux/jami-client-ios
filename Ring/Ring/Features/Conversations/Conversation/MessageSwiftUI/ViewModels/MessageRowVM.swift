/*
 *  Copyright (C) 2022 Savoir-faire Linux Inc.
 *
 *  Author: Silbino Gonçalves Matado <silbino.gmatado@savoirfairelinux.com>
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
 *  Author: Andreas Traczyk <andreas.traczyk@savoirfairelinux.com>
 *  Author: Raphaël Brulé <raphael.brule@savoirfairelinux.com>
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

class MessageRowVM: ObservableObject, MessageAppearanceProtocol, MessageReadObserver, AvatarImageObserver {
    @Published var avatarImage: UIImage?
    @Published var read: [UIImage]?
    @Published var timeString: String = ""
    @Published var topSpace: CGFloat = 0
    @Published var bottomSpace: CGFloat = 0
    @Published var leadingSpace: CGFloat = 0
    @Published var readBorderColor: Color
    @Published var showSentIndicator: Bool = false
    @Published var showReciveIndicator: Bool = false
    var styling: MessageStyling = MessageStyling()
    var incoming: Bool
    private var infoState: PublishSubject<State>?
    var centeredMessage: Bool

    var message: MessageModel
    var disposeBag = DisposeBag()

    var shouldShowTimeString = false {
        didSet {
            self.timeString = self.shouldShowTimeString ? self.getTimeLabelString() : ""
        }
    }

    var shouldDisplayAavatar = false {
        didSet {
            let jamiId = message.uri.isEmpty ? message.authorId : message.uri
            if self.shouldDisplayAavatar {
                self.infoState?.onNext(MessageInfo.updateAvatar(jamiId: jamiId, message: self))
            } else {
                self.avatarImage = nil
            }
        }
    }

    func updateImage(image: UIImage, jamiId: String) {
        let localId = message.uri.isEmpty ? message.authorId : message.uri
        if jamiId == localId {
            self.avatarImage = image
        }
    }

    var sequencing: MessageSequencing = .unknown {
        didSet {
            topSpace = (sequencing == .singleMessage || sequencing == .firstOfSequence) ? 2 : 0
            bottomSpace = (sequencing == .singleMessage || sequencing == .lastOfSequence) ? 2 : 0
        }
    }

    func fetchLastRead() {
        self.infoState?.onNext(MessageInfo.updateRead(messageId: self.message.id, message: self))
    }

    init(message: MessageModel) {
        self.message = message
        self.incoming = message.incoming
        self.centeredMessage = message.type == .contact || message.type == .initial
        self.readBorderColor = Color(UIColor.systemBackground)
        self.timeString = getTimeLabelString()
        self.updateMessageStatus()
    }

    func setInfoState(state: PublishSubject<State>) {
        self.infoState = state
    }

    func getTimeLabelString() -> String {
        let time = self.message.receivedDate
        // get the current time
        let currentDateTime = Date()

        // prepare formatter
        let dateFormatter = DateFormatter()

        if Calendar.current.compare(currentDateTime, to: time, toGranularity: .day) == .orderedSame {
            // age: [0, received the previous day[
            dateFormatter.dateFormat = "h:mma"
        } else if Calendar.current.compare(currentDateTime, to: time, toGranularity: .weekOfYear) == .orderedSame {
            // age: [received the previous day, received 7 days ago[
            dateFormatter.dateFormat = "E h:mma"
        } else if Calendar.current.compare(currentDateTime, to: time, toGranularity: .year) == .orderedSame {
            // age: [received 7 days ago, received the previous year[
            dateFormatter.dateFormat = "MMM d, h:mma"
        } else {
            // age: [received the previous year, inf[
            dateFormatter.dateFormat = "MMM d, yyyy h:mma"
        }

        // generate the string containing the message time
        return dateFormatter.string(from: time).uppercased()
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
