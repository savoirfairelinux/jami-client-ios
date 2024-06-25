/*
 *  Copyright (C) 2017-2022 Savoir-faire Linux Inc.
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

class MessageContainerModel: Identifiable {
    let id: String
    let messageContent: MessageContentVM
    let messageRow: MessageRowVM
    let stackViewModel: MessageStackVM
    let contactViewModel: ContactMessageVM
    let message: MessageModel
    let disposeBag = DisposeBag()
    let replyTarget: MessageReplyTargetVM
    let reactionsModel: ReactionsContainerModel

    // message info state
    private let infoSubject = PublishSubject<State>()
    lazy var messageInfoState: Observable<State> = self.infoSubject.asObservable()

    // message transfer state
    private let transferSubject = PublishSubject<State>()
    lazy var messageTransferState: Observable<State> = self.transferSubject.asObservable()

    var shouldShowTimeString: Bool = false {
        didSet {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.messageRow.shouldShowTimeString = self.shouldShowTimeString
            }
        }
    }

    var shouldDisplayContactInfo: Bool = false {
        didSet {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.stackViewModel.shouldDisplayName = self.shouldDisplayContactInfo
                self.messageRow.shouldDisplayAavatar = self.shouldDisplayContactInfo
            }
        }
    }

    var shouldDisplayContactInfoForConversation: Bool = false {
        didSet {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.messageRow
                    .shouldDisplayContactInfoForConversation(state: self
                                                                .shouldDisplayContactInfoForConversation)
            }
        }
    }

    var sequencing: MessageSequencing = .unknown {
        didSet {
            messageContent.setSequencing(sequencing: sequencing)
            messageRow.setSequencing(sequencing: sequencing)
        }
    }

    var preferencesColor: UIColor

    init(
        message: MessageModel,
        contextMenuState: PublishSubject<State>,
        isHistory: Bool,
        localJamiId: String,
        preferencesColor: UIColor
    ) {
        id = message.id
        self.message = message
        self.preferencesColor = preferencesColor
        stackViewModel = MessageStackVM(message: message)
        messageContent = MessageContentVM(
            message: message,
            contextMenuState: contextMenuState,
            transferState: transferSubject,
            isHistory: isHistory,
            preferencesColor: preferencesColor
        )
        messageRow = MessageRowVM(message: message)
        contactViewModel = ContactMessageVM(message: message)
        replyTarget = MessageReplyTargetVM(
            contextMenuState: contextMenuState,
            localJamiId: localJamiId,
            replyAuthorJamiId: message.authorId,
            isIncoming: message.incoming
        )
        reactionsModel = ReactionsContainerModel(message: message)
    }

    func listenerForInfoStateAdded() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.stackViewModel.setInfoState(state: self.infoSubject)
            self.messageContent.setInfoState(state: self.infoSubject)
            self.messageRow.setInfoState(state: self.infoSubject)
            self.contactViewModel.setInfoState(state: self.infoSubject)
            self.replyTarget.setInfoState(state: self.infoSubject)
            self.reactionsModel.setInfoState(state: self.infoSubject)
        }
    }

    func setReplyTarget(message: MessageModel) {
        let target = MessageContentVM(
            message: message,
            contextMenuState: PublishSubject<State>(),
            transferState: transferSubject,
            isHistory: false,
            preferencesColor: preferencesColor
        )
        target.setInfoState(state: infoSubject)
        replyTarget.target = target
    }

    func updateTransferStatus(status: DataTransferStatus) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.messageContent.setTransferStatus(transferStatus: status)
        }

        if let reply = replyTarget.target {
            DispatchQueue.main.async { [weak reply] in
                guard let reply = reply else { return }
                reply.setTransferStatus(transferStatus: status)
            }
        }
    }

    func startTargetReplyAnimation() {
        messageContent.startTargetReplyAnimation()
    }

    func swarmColorUpdated(color: UIColor) {
        messageContent.swarmColorUpdated(color: color)
        contactViewModel.swarmColorUpdated(color: color)
    }

    func reactionsUpdated() {
        reactionsModel.reactionsUpdated()
    }

    func messageUpdated() {
        messageContent.updateMessageEditions()
        messageRow.updateMessageStatus()
    }

    func displayLastSent(state: Bool) {
        messageRow.displayLastSent(state: state)
    }

    func hasReactions() -> Bool {
        return !message.reactions.isEmpty
    }
}
