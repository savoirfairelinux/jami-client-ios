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

class MessageContainerModel: Identifiable, Equatable {
    let id: String
    let messageContent: MessageContentVM
    let messageRow: MessageRowVM
    let stackViewModel: MessageStackVM
    let contactViewModel: ContactMessageVM
    /// Only for `.collabDocument`; every other message leaves it nil.
    let collabDocViewModel: CollabDocMessageVM?
    private(set) var message: MessageModel
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

    var startsNewDay: Bool = false {
        didSet {
            guard oldValue != startsNewDay else { return }
            self.messageRow.startsNewDay = startsNewDay
        }
    }

    var endsEmojiRun: Bool = true {
        didSet {
            guard oldValue != endsEmojiRun else { return }
            self.messageContent.setEndsEmojiRun(endsEmojiRun)
        }
    }

    var shouldDisplayName: Bool = false {
        didSet {
            guard oldValue != shouldDisplayName else { return }
            self.stackViewModel.shouldDisplayName = shouldDisplayName
        }
    }

    var shouldDisplayAvatar: Bool = false {
        didSet {
            guard oldValue != shouldDisplayAvatar else { return }
            self.messageRow.shouldDisplayAavatar = shouldDisplayAvatar
        }
    }

    var shouldDisplayContactInfoForConversation: Bool = false {
        didSet {
            guard oldValue != shouldDisplayContactInfoForConversation else { return }
            self.messageRow.shouldDisplayContactInfoForConversation(state: shouldDisplayContactInfoForConversation)
        }
    }

    var sequencing: MessageSequencing = .unknown {
        didSet {
            self.messageRow.setSequencing(sequencing: sequencing)
        }
    }

    var bubbleSequencing: MessageSequencing = .unknown {
        didSet {
            self.messageContent.setSequencing(sequencing: bubbleSequencing)
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
        self.collabDocViewModel = message.type == .collabDocument
            ? CollabDocMessageVM(message: message, contextMenuState: contextMenuState) : nil
        self.replyTarget = MessageReplyTargetVM(contextMenuState: contextMenuState, localJamiId: localJamiId, isIncoming: message.incoming)
        self.reactionsModel = ReactionsContainerModel(message: message, localJamiId: localJamiId)
        self.messageContent.setHasReactions(!message.reactions.isEmpty)
    }

    func listenerForInfoStateAdded() {
        self.stackViewModel.setInfoState(state: self.infoSubject)
        self.messageContent.setInfoState(state: self.infoSubject)
        self.messageRow.setInfoState(state: self.infoSubject)
        self.contactViewModel.setInfoState(state: self.infoSubject)
        self.reactionsModel.setInfoState(state: self.infoSubject)
    }

    func setReplyTarget(message: MessageModel) {
        let target = MessageContentVM(message: message, contextMenuState: PublishSubject<State>(), transferState: self.transferSubject, isHistory: false, preferencesColor: preferencesColor)
        target.maxImageSize = 100
        target.setInfoState(state: self.infoSubject)
        self.replyTarget.target = target
    }

    func startTargetReplyAnimation() {
        self.messageContent.startTargetReplyAnimation()
    }

    func swarmColorUpdated(color: UIColor) {
        self.messageContent.swarmColorUpdated(color: color)
    }

    func reactionsUpdated(_ message: MessageModel) {
        self.apply(message)
        self.reactionsModel.reactionsUpdated()
    }

    func messageUpdated(_ message: MessageModel) {
        self.apply(message)
        self.messageContent.updateMessageEditions()
        self.messageRow.updateMessageStatus()
        self.collabDocViewModel?.messageUpdated()
        if message.type == .fileTransfer {
            self.messageContent.setTransferStatus(transferStatus: message.transferStatus)
        }
    }

    func refreshDates() {
        self.messageContent.refreshDates()
        self.messageRow.refreshDates()
    }

    private func apply(_ message: MessageModel) {
        self.message = message
        self.stackViewModel.message = message
        self.messageContent.message = message
        self.messageRow.message = message
        self.contactViewModel.message = message
        self.collabDocViewModel?.message = message
        self.reactionsModel.message = message
        self.messageContent.setHasReactions(!message.reactions.isEmpty)
    }

    func displayLastSent(state: Bool) {
        self.messageRow.displayLastSent(state: state)
    }

    func hasReactions() -> Bool {
        return !self.message.reactions.isEmpty
    }

    static func == (lhs: MessageContainerModel, rhs: MessageContainerModel) -> Bool {
        return lhs.id == rhs.id
    }
}
