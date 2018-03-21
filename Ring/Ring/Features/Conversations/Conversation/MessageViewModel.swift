/*
 *  Copyright (C) 2017 Savoir-faire Linux Inc.
 *
 *  Author: Silbino Gonçalves Matado <silbino.gmatado@savoirfairelinux.com>
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

import RxSwift
import SwiftyBeaver

enum BubblePosition {
    case received
    case sent
    case generated
}

enum MessageSequencing {
    case singleMessage
    case firstOfSequence
    case lastOfSequence
    case middleOfSequence
    case unknown
}

enum GeneratedMessageType: String {
    case receivedContactRequest = "Contact request received"
    case contactAdded = "Contact added"
    case missedIncomingCall = "Missed incoming call"
    case missedOutgoingCall = "Missed outgoing call"
    case incomingCall = "Incoming call"
    case outgoingCall = "Outgoing call"
}

class MessageViewModel {

    fileprivate let log = SwiftyBeaver.self

    fileprivate let accountService: AccountsService
    fileprivate let conversationsService: ConversationsService
    fileprivate let dataTransferService: DataTransferService
    var message: MessageModel
    var timeStringShown: String?
    var sequencing: MessageSequencing = .unknown

    private let disposeBag = DisposeBag()

    init(withInjectionBag injectionBag: InjectionBag,
         withMessage message: MessageModel) {
        self.accountService = injectionBag.accountService
        self.conversationsService = injectionBag.conversationsService
        self.dataTransferService = injectionBag.dataTransferService
        self.message = message
        self.initialTransferStatus = message.transferStatus
        self.timeStringShown = nil
        self.status.onNext(message.status)

        if isTransfer {
            if let transferId = daemonId,
                self.conversationsService.dataTransferMessageMap[transferId] == nil {
                self.conversationsService.dataTransferMessageMap.removeValue(forKey: transferId)
                switch self.initialTransferStatus {
                case .awaiting:
                    message.transferStatus = .error
                    self.initialTransferStatus = .error
                case .created, .ongoing:
                    self.initialTransferStatus = .error
                default: break
                }
            }
            self.conversationsService
                .sharedResponseStream
                .filter({ (transferEvent) in
                    guard let transferId: UInt64 = transferEvent.getEventInput(ServiceEventInput.transferId) else { return false }
                    return  transferEvent.eventType == ServiceEventType.dataTransferMessageUpdated &&
                            transferId == self.daemonId
                })
                .subscribe(onNext: { [unowned self] transferEvent in
                    guard   let transferId: UInt64 = transferEvent.getEventInput(ServiceEventInput.transferId),
                            let transferInfo = self.dataTransferService.getTransferInfo(withId: transferId) else {
                        self.log.error("MessageViewModel: can't find transferInfo")
                        return
                    }
                    self.log.debug("MessageViewModel: dataTransferMessageUpdated - id:\(transferId) status:\(stringFromEventCode(with: transferInfo.lastEvent))")
                    var transferStatus: DataTransferStatus = .unknown
                    switch transferInfo.lastEvent {
                    case .closed_by_host, .closed_by_peer:
                        transferStatus = DataTransferStatus.canceled
                    case .invalid, .unsupported, .invalid_pathname, .unjoinable_peer:
                        transferStatus = DataTransferStatus.error
                    case .wait_peer_acceptance, .wait_host_acceptance:
                        transferStatus = DataTransferStatus.awaiting
                    case .ongoing:
                        transferStatus = DataTransferStatus.ongoing
                    case .finished:
                        transferStatus = DataTransferStatus.success
                    case .created:
                        transferStatus = DataTransferStatus.created
                    }
                    self.message.transferStatus = transferStatus
                    self.transferStatus.onNext(transferStatus)
                })
                .disposed(by: disposeBag)
        } else {
            // subscribe to message status updates for outgoing messages
            self.conversationsService
                .sharedResponseStream
                .filter({ messageUpdateEvent in
                    guard let accountId: String = messageUpdateEvent.getEventInput(.id) else { return false }
                    let account = self.accountService.getAccount(fromAccountId: accountId)
                    let accountHelper = AccountModelHelper(withAccount: account!)
                    return messageUpdateEvent.eventType == ServiceEventType.messageStateChanged &&
                        messageUpdateEvent.getEventInput(.messageId) == self.message.daemonId &&
                        accountHelper.ringId == self.message.author
                })
                .subscribe(onNext: { [unowned self] messageUpdateEvent in
                    if let status: MessageStatus = messageUpdateEvent.getEventInput(.messageStatus) {
                        self.status.onNext(status)
                    }
                })
                .disposed(by: self.disposeBag)
        }
    }

    var content: String {
        return self.message.content
    }

    var receivedDate: Date {
        return self.message.receivedDate
    }

    var daemonId: UInt64? {
        return UInt64(self.message.daemonId)
    }

    var messageId: Int64 {
        return self.message.messageId
    }

    var isTransfer: Bool {
        return self.message.isTransfer
    }

    var shouldDisplayTransferedImage: Bool {
        if !self.isTransfer {
            return false
        }
        if !self.message.incoming &&
            (   self.message.transferStatus != .error ||
                self.message.transferStatus != .canceled) {
            return true
        }

        if self.message.transferStatus == .success {
            return true
        }

        return false
    }

    var status = BehaviorSubject<MessageStatus>(value: .unknown)

    var transferStatus = BehaviorSubject<DataTransferStatus>(value: .unknown)
    var lastTransferStatus: DataTransferStatus = .unknown
    var initialTransferStatus: DataTransferStatus

    func bubblePosition() -> BubblePosition {
        if self.message.isGenerated {
            return .generated
        }

        if self.message.incoming {
            return .received
        } else {
            return .sent
        }
    }

    typealias TransferParsingTuple = (fileName: String, fileSize: String?, identifier: String?)

    var transferFileData: TransferParsingTuple {
        let contentArr = self.content.components(separatedBy: "\n")
        var name: String
        var identifier: String?
        var size: String?
        if contentArr.count > 2 {
            name = contentArr[0]
            size = contentArr[1]
            identifier = contentArr[2]
        } else if contentArr.count > 1 {
            name = contentArr[0]
            size = contentArr[1]
        } else {
            name = content
        }
        return (name, size, identifier)
    }

    func transferedFile() -> URL? {
        if !self.message.incoming {return nil}
        if self.lastTransferStatus != .success &&
            self.message.transferStatus != .success {
            return nil
        }
        let transferInfo = transferFileData
        return self.dataTransferService
            .getFileUrl(fileName: transferInfo.fileName)
    }

    func getTransferedImage(maxSize: CGFloat) -> UIImage? {
        if self.message.incoming &&
            self.lastTransferStatus != .success &&
            self.message.transferStatus != .success {
            return nil
        }
        let transferInfo = transferFileData
        return self.dataTransferService
            .getImage(for: transferInfo.fileName,
                      maxSize: maxSize,
                      identifier: transferInfo.identifier)
    }
}
