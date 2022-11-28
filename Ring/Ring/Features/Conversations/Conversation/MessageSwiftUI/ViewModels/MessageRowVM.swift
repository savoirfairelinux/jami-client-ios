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

class MessageRowVM: ObservableObject {
    @Published var avatarImage: UIImage?
    @Published var read: [UIImage]?
    @Published var timeString: String = ""
    @Published var topSpace: CGFloat = 0
    @Published var bottomSpace: CGFloat = 0
    var incoming: Bool
    var infoState: PublishSubject<State>
    var centeredMessage: Bool

    var message: MessageModel

    var shouldShowTimeString = false {
        didSet {
            self.timeString = self.shouldShowTimeString ? self.getTimeLabelString() : ""
        }
    }

    var shouldDisplayAavatar = false {
        didSet {
            let jamiId = message.uri.isEmpty ? message.authorId : message.uri
            if self.shouldDisplayAavatar {
                self.infoState.onNext(MessageInfo.updateAvatar(jamiId: jamiId))
            }
        }
    }

    var sequencing: MessageSequencing = .unknown {
        didSet {
            topSpace = (sequencing == .singleMessage || sequencing == .firstOfSequence) ? 10 : 0
            bottomSpace = (sequencing == .singleMessage || sequencing == .lastOfSequence) ? 10 : 0
            let shouldDisplayAavatar = (sequencing == .lastOfSequence || sequencing == .singleMessage) && self.message.incoming
            self.shouldDisplayAavatar = shouldDisplayAavatar
        }
    }

    func fetchLastRead() {
        self.infoState.onNext(MessageInfo.updateRead(messageId: self.message.id))
    }

    init(message: MessageModel, infoState: PublishSubject<State>) {
        self.message = message
        self.incoming = message.incoming
        self.infoState = infoState
        self.centeredMessage = message.type == .contact || message.type == .initial
        self.timeString = getTimeLabelString()
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
}
