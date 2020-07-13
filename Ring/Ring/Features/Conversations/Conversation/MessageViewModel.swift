/*
 *  Copyright (C) 2017-2020 Savoir-faire Linux Inc.
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

import RxSwift
import RxCocoa
import SwiftyBeaver
import MobileCoreServices

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
    case contactAdded =  "Contact added"
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

    var shouldShowTimeString: Bool = false
    lazy var timeStringShown: String = { [unowned self] in
        return MessageViewModel.getTimeLabelString(forTime: self.receivedDate)
    }()

    var sequencing: MessageSequencing = .unknown
    var isComposingIndicator: Bool = false

    var isLocationSharingBubble: Bool = false

    private let disposeBag = DisposeBag()
    let injectBug: InjectionBag

    init(withInjectionBag injectionBag: InjectionBag,
         withMessage message: MessageModel, isLastDisplayed: Bool) {
        self.accountService = injectionBag.accountService
        self.conversationsService = injectionBag.conversationsService
        self.dataTransferService = injectionBag.dataTransferService
        self.injectBug = injectionBag
        self.message = message
        self.initialTransferStatus = message.transferStatus
        self.status.onNext(message.status)
        self.displayReadIndicator.accept(isLastDisplayed)

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
                .filter({ [weak self] (transferEvent) in
                    guard let transferId: UInt64 = transferEvent.getEventInput(ServiceEventInput.transferId) else { return false }
                    return  transferEvent.eventType == ServiceEventType.dataTransferMessageUpdated &&
                        transferId == self?.daemonId
                })
                .subscribe(onNext: { [weak self] transferEvent in
                    guard   let transferId: UInt64 = transferEvent.getEventInput(ServiceEventInput.transferId),
                        let transferStatus: DataTransferStatus = transferEvent.getEventInput(ServiceEventInput.state) else {
                        return
                    }
                    self?.log.debug("MessageViewModel: dataTransferMessageUpdated - id:\(transferId) status:\(transferStatus)")
                    self?.message.transferStatus = transferStatus
                    self?.transferStatus.onNext(transferStatus)
                })
                .disposed(by: disposeBag)
        } else {
            // subscribe to message status updates for outgoing messages
            self.conversationsService
                .sharedResponseStream
                .filter({ [weak self] messageUpdateEvent in
                    return messageUpdateEvent.eventType == ServiceEventType.messageStateChanged &&
                        messageUpdateEvent.getEventInput(.messageId) == self?.message.daemonId &&
                        !(self?.message.incoming ?? false)
                })
                .subscribe(onNext: { [weak self] messageUpdateEvent in
                    if let status: MessageStatus = messageUpdateEvent.getEventInput(.messageStatus) {
                        self?.status.onNext(status)
                    }
                })
                .disposed(by: self.disposeBag)
            self.conversationsService
                .sharedResponseStream
                .filter({ [weak self] messageUpdateEvent in
                    let event = messageUpdateEvent.eventType == ServiceEventType.lastDisplayedMessageUpdated
                    let message = messageUpdateEvent
                        .getEventInput(.oldDisplayedMessage) == self?.message.messageId ||
                    messageUpdateEvent
                        .getEventInput(.newDisplayedMessage) == self?.message.messageId
                    return event && message
                })
                .subscribe(onNext: { [weak self] messageUpdateEvent in
                    if let oldMessage: Int64 = messageUpdateEvent.getEventInput(.oldDisplayedMessage),
                        oldMessage == self?.message.messageId {
                        self?.displayReadIndicator.accept(false)
                    } else if let newMessage: Int64 = messageUpdateEvent.getEventInput(.newDisplayedMessage),
                        newMessage == self?.message.messageId {
                        self?.displayReadIndicator.accept(true)
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
    var displayReadIndicator = BehaviorRelay<Bool>(value: false)

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

    func transferedFile(conversationID: String) -> URL? {
        guard let account = self.accountService.currentAccount else {return nil}
        if self.lastTransferStatus != .success &&
            self.message.transferStatus != .success {
            return nil
        }
        let transferInfo = transferFileData
        let folderName = self.message.incoming ? Directories.downloads.rawValue : Directories.recorded.rawValue
        return self.dataTransferService
            .getFileUrl(fileName: transferInfo.fileName,
                        inFolder: folderName,
                        accountID: account.id,
                        conversationID: conversationID)
    }

    func getPlayer(conversationViewModel: ConversationViewModel) -> PlayerViewModel? {
        if self.lastTransferStatus != .success &&
            self.message.transferStatus != .success {
            return nil
        }

        if let playerModel = conversationViewModel.getPlayer(messageID: String(self.messageId)) {
            return playerModel
        }
        let transferInfo = transferFileData
        let name = transferInfo.fileName
        guard let fileExtension = NSURL(fileURLWithPath: name).pathExtension else {
            return nil
        }
        if fileExtension.isMediaExtension() {
            // first search for incoming video in downloads folder and for outgoing in recorded
            let folderName = self.message.incoming ? Directories.downloads.rawValue : Directories.recorded.rawValue
            var path = self.dataTransferService
                .getFileUrl(fileName: name,
                            inFolder: folderName,
                            accountID: conversationViewModel.conversation.value.accountId,
                            conversationID: conversationViewModel.conversation.value.conversationId)
            var pathString =  path?.path ?? ""
            if pathString.isEmpty && self.message.incoming {
                return nil
            } else if pathString.isEmpty {
                // try to search outgoing video in downloads folder
                path = self.dataTransferService
                    .getFileUrl(fileName: name,
                                inFolder: Directories.downloads.rawValue,
                                accountID: conversationViewModel.conversation.value.accountId,
                                conversationID: conversationViewModel.conversation.value.conversationId)
                pathString =  path?.path ?? ""
                if pathString.isEmpty {
                    return nil
                }
            }
            let model = PlayerViewModel(injectionBag: injectBug, path: pathString)
            conversationViewModel.setPlayer(messageID: String(self.messageId), player: model)
            return model
        }
        return nil
    }

    func getTransferedImage(maxSize: CGFloat,
                            conversationID: String,
                            accountId: String) -> UIImage? {
        guard let account = self.accountService
            .getAccount(fromAccountId: accountId) else {return nil}
        if self.message.incoming &&
            self.lastTransferStatus != .success &&
            self.message.transferStatus != .success {
            return nil
        }
        let transferInfo = transferFileData
        return self.dataTransferService
            .getImage(for: transferInfo.fileName,
                      maxSize: maxSize,
                      identifier: transferInfo.identifier,
                      accountID: account.id,
                      conversationID: conversationID)
    }

    private static func getTimeLabelString(forTime time: Date) -> String {
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
