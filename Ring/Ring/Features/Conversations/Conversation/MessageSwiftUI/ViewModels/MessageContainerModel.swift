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
    lazy var messageInfoState: Observable<State> = {
        return self.infoSubject.asObservable()
    }()

    // message transfer state
    private let transferSubject = PublishSubject<State>()
    lazy var messageTransferState: Observable<State> = {
        return self.transferSubject.asObservable()
    }()

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
                self.messageRow.shouldDisplayAvatar = self.shouldDisplayContactInfo
            }
        }
    }

    var shouldDisplayContactInfoForConversation: Bool = false {
        didSet {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.messageRow.shouldDisplayContactInfoForConversation(state: self.shouldDisplayContactInfoForConversation)
            }
        }
    }

    var sequencing: MessageSequencing = .unknown {
        didSet {
            self.messageContent.setSequencing(sequencing: sequencing)
            self.messageRow.setSequencing(sequencing: sequencing)
        }
    }

    var preferencesColor: UIColor

    init(message: MessageModel, contextMenuState: PublishSubject<State>, isHistory: Bool, localJamiId: String, preferencesColor: UIColor) {
        self.id = message.id
        self.message = message
        self.preferencesColor = preferencesColor
        self.stackViewModel = MessageStackVM(message: message)
        self.messageContent = MessageContentVM(message: message, contextMenuState: contextMenuState, transferState: self.transferSubject, isHistory: isHistory, preferencesColor: preferencesColor)
        self.messageRow = MessageRowVM(message: message)
        self.contactViewModel = ContactMessageVM(message: message)
        self.replyTarget = MessageReplyTargetVM(contextMenuState: contextMenuState, localJamiId: localJamiId, replyAuthorJamiId: message.authorId, isIncoming: message.incoming)
        self.reactionsModel = ReactionsContainerModel(message: message, swarmColor: preferencesColor, localJamiId: localJamiId)
    }

    func listenerForInfoStateAdded() {
        DispatchQueue.main.async {[weak self] in
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
        let target = MessageContentVM(message: message, contextMenuState: PublishSubject<State>(), transferState: self.transferSubject, isHistory: false, preferencesColor: preferencesColor)
        target.setInfoState(state: self.infoSubject)
        self.replyTarget.target = target
    }

    func updateTransferStatus(status: DataTransferStatus) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.messageContent.setTransferStatus(transferStatus: status)
        }

        if let reply = self.replyTarget.target {
            DispatchQueue.main.async { [weak reply] in
                guard let reply = reply else { return }
                reply.setTransferStatus(transferStatus: status)
            }
        }
    }

    func startTargetReplyAnimation() {
        self.messageContent.startTargetReplyAnimation()
    }

    func swarmColorUpdated(color: UIColor) {
        self.messageContent.swarmColorUpdated(color: color)
        self.contactViewModel.swarmColorUpdated(color: color)
    }

    func reactionsUpdated() {
        self.reactionsModel.reactionsUpdated()
    }

    func messageUpdated() {
        self.messageContent.updateMessageEditions()
        self.messageRow.updateMessageStatus()
    }

    func displayLastSent(state: Bool) {
        self.messageRow.displayLastSent(state: state)
    }

    func hasReactions() -> Bool {
        return !self.message.reactions.isEmpty
    }
}
