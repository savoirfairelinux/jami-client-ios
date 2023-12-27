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

class MessageContainerModel: Identifiable {
    let id: String
    let messageContent: MessageContentVM
    let messageRow: MessageRowVM
    let stackViewModel: MessageStackVM
    let contactViewModel: ContactMessageVM
    let message: MessageModel
    let disposeBag = DisposeBag()
    var replyTarget: MessageReplyTargetVM

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

    // context menu state
    private let contextMenuState: PublishSubject<State>

    var shouldShowTimeString: Bool = false {
        didSet {
            self.messageRow.shouldShowTimeString = shouldShowTimeString
        }
    }

    var shouldDisplayName: Bool = false {
        didSet {
            self.stackViewModel.shouldDisplayName = self.shouldDisplayName
        }
    }

    var sequencing: MessageSequencing = .unknown {
        didSet {
            self.messageContent.setSequencing(sequencing: sequencing)
            self.messageRow.sequencing = sequencing
        }
    }

    var followEmogiMessage = false {
        didSet {
            self.messageContent.followEmogiMessage = followEmogiMessage
            self.messageRow.followEmogiMessage = followEmogiMessage
            if let reply = self.replyTarget.target {
                reply.followEmogiMessage = followEmogiMessage
            }
        }
    }
    var followingByEmogiMessage = false {
        didSet {
            self.messageContent.followingByEmogiMessage = followingByEmogiMessage
            if let reply = self.replyTarget.target {
                reply.followingByEmogiMessage = followingByEmogiMessage
            }
            self.messageRow.followingByEmogiMessage = followingByEmogiMessage
        }
    }

    var isReply: Bool {
        return self.messageContent.isReply
    }

    init(message: MessageModel, contextMenuState: PublishSubject<State>, localJamiId: String) {
        self.id = message.id
        self.message = message
        self.contextMenuState = contextMenuState
        self.stackViewModel = MessageStackVM(message: message, infoState: self.infoSubject)
        self.messageContent = MessageContentVM(message: message, contextMenuState: contextMenuState, transferState: self.transferSubject)
        self.messageRow = MessageRowVM(message: message, infoState: self.infoSubject)
        self.contactViewModel = ContactMessageVM(message: message, infoState: self.infoSubject)
        self.replyTarget = MessageReplyTargetVM(infoState: self.infoSubject, localJamiId: localJamiId, replyAuthorJamiId: message.authorId, isIncoming: message.incoming)
    }

    func setReplyTarget(message: MessageModel) {
        let target = MessageContentVM(message: message, contextMenuState: PublishSubject<State>(), transferState: self.transferSubject)
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

    func updateRead(avatars: [UIImage]?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.messageRow.read = avatars
        }
    }

    func updateAvatar(image: UIImage) {
        DispatchQueue.main.async { [weak self, weak image] in
            guard let self = self, let image = image else { return }
            if self.messageRow.shouldDisplayAavatar && self.message.incoming {
                self.messageRow.avatarImage = image
            }
            if self.message.type == .contact && self.message.incoming {
                self.contactViewModel.avatarImage = image
            }

            if self.replyTarget.target != nil {
                self.replyTarget.avatarImage = image
            }
        }
    }

    func updateUsername(name: String, jamiId: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.stackViewModel.shouldDisplayName && self.message.incoming {
                self.stackViewModel.username = name
            }
            if self.message.type == .contact && self.message.incoming {
                self.contactViewModel.username = name
            }

            if  self.replyTarget.target != nil {
                self.replyTarget.updateUsername(name: name, jamiId: jamiId)
            }
        }
    }

    func swarmColorUpdated(color: UIColor) {
        self.messageContent.swarmColorUpdated(color: color)
        self.contactViewModel.swarmColorUpdated(color: color)
    }
}
