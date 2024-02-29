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
    case contactAdded = "Contact added"
    case missedIncomingCall = "Missed incoming call"
    case missedOutgoingCall = "Missed outgoing call"
    case incomingCall = "Incoming call"
    case outgoingCall = "Outgoing call"
}

class MessageViewModel {

    private let log = SwiftyBeaver.self

    private let accountService: AccountsService
    private let conversationsService: ConversationsService
    private let dataTransferService: DataTransferService
    private let profileService: ProfilesService
    var message: MessageModel
    var metaData: LPLinkMetadata?

    var profileImageData = BehaviorRelay<Data?>(value: nil)

    var shouldShowTimeString: Bool = false
    lazy var timeStringShown: String = { [weak self] in
        guard let self = self else { return "" }
        return MessageViewModel.getTimeLabelString(forTime: self.receivedDate)
    }()

    var sequencing: MessageSequencing = .unknown
    var isComposingIndicator: Bool = false

    var isText: Bool { return self.message.type == .text }

    private let disposeBag = DisposeBag()
    let injectBug: InjectionBag

    init(withInjectionBag injectionBag: InjectionBag,
         withMessage message: MessageModel, isLastDisplayed: Bool) {
        self.accountService = injectionBag.accountService
        self.conversationsService = injectionBag.conversationsService
        self.dataTransferService = injectionBag.dataTransferService
        self.profileService = injectionBag.profileService
        self.injectBug = injectionBag
        self.message = message
        self.initialTransferStatus = message.transferStatus
        self.status.onNext(message.status)
        self.displayReadIndicator = BehaviorRelay<Bool>(value: isLastDisplayed)
        // self.displayReadIndicator.accept(isLastDisplayed)
        self.subscribeProfileServiceContactPhoto()

        if isTransfer {
            self.conversationsService
                .sharedResponseStream
                .filter({ [weak self] (transferEvent) in
                    guard let transferId: String = transferEvent.getEventInput(ServiceEventInput.transferId) else { return false }
                    return  transferEvent.eventType == ServiceEventType.dataTransferMessageUpdated &&
                        self?.daemonId == transferId
                })
                .subscribe(onNext: { [weak self] transferEvent in
                    guard let transferId: String = transferEvent.getEventInput(ServiceEventInput.transferId),
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
                    let event = messageUpdateEvent.eventType == ServiceEventType.lastDisplayedMessageUpdated
                    let message = messageUpdateEvent
                        .getEventInput(.oldDisplayedMessage) == self?.message.id ||
                        messageUpdateEvent
                        .getEventInput(.newDisplayedMessage) == self?.message.id
                    return event && message
                })
                .subscribe(onNext: { [weak self] messageUpdateEvent in
                    if let oldMessage: String = messageUpdateEvent.getEventInput(.oldDisplayedMessage),
                       oldMessage == self?.message.id {
                        print("@@@@@last displayed removed", message.id)
                        self?.displayReadIndicator.accept(false)
                    } else if let newMessage: String = messageUpdateEvent.getEventInput(.newDisplayedMessage),
                              newMessage == self?.message.id {
                        print("@@@@@last displayed added", message.id)
                        self?.displayReadIndicator.accept(true)
                    }
                })
                .disposed(by: self.disposeBag)
        }
    }

    private func subscribeProfileServiceContactPhoto() {
        guard let account = self.accountService.currentAccount else { return }
        let schema: URIType = account.type == .sip ? .sip : .ring
        guard let contactURI = JamiURI(schema: schema, infoHash: self.message.authorId).uriString else { return }
        self.profileService
            .getProfile(uri: contactURI,
                        createIfNotexists: false,
                        accountId: account.id)
            .subscribe(onNext: { [weak self] profile in
                if let photo = profile.photo,
                   let data = NSData(base64Encoded: photo, options: NSData.Base64DecodingOptions.ignoreUnknownCharacters) as Data? {
                    self?.profileImageData.accept(data)
                }
            })
            .disposed(by: disposeBag)
    }

    var content: String {
        return self.message.content
    }

    var receivedDate: Date {
        return self.message.receivedDate
    }

    var daemonId: String {
        return self.message.daemonId
    }

    var messageId: String {
        return self.message.id
    }

    var isTransfer: Bool {
        return self.message.type == .fileTransfer
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
    let displayReadIndicator: BehaviorRelay<Bool>

    var transferStatus = BehaviorSubject<DataTransferStatus>(value: .unknown)
    var lastTransferStatus: DataTransferStatus = .unknown
    var initialTransferStatus: DataTransferStatus

    func bubblePosition() -> BubblePosition {
        if self.message.type == .call || self.message.type == .contact {
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

    func getURLFromPhotoLibrary(conversationID: String, completionHandler: @escaping (URL?) -> Void) -> Bool {
        return false
    }

    func removeFile(conversationID: String, accountId: String, isSwarm: Bool) {
        guard let url = self.transferedFile(conversationID: conversationID, accountId: accountId, isSwarm: isSwarm) else { return }
        self.dataTransferService.removeFile(at: url)
    }

    func transferedFile(conversationID: String, accountId: String, isSwarm: Bool) -> URL? {
        if self.lastTransferStatus != .success &&
            self.message.transferStatus != .success {
            return nil
        }
        let transferInfo = transferFileData
        if isSwarm {
            return self.dataTransferService.getFileUrlForSwarm(fileName: self.message.daemonId, accountID: accountId, conversationID: conversationID)
        }
        if self.message.incoming {
            return self.dataTransferService
                .getFileUrlNonSwarm(fileName: transferInfo.fileName,
                                    inFolder: Directories.downloads.rawValue,
                                    accountID: accountId,
                                    conversationID: conversationID)
        }

        let recorded = self.dataTransferService
            .getFileUrlNonSwarm(fileName: transferInfo.fileName,
                                inFolder: Directories.recorded.rawValue,
                                accountID: accountId,
                                conversationID: conversationID)
        guard recorded == nil, recorded?.path.isEmpty ?? true else { return recorded }
        return self.dataTransferService
            .getFileUrlNonSwarm(fileName: transferInfo.fileName,
                                inFolder: Directories.downloads.rawValue,
                                accountID: accountId,
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
        let name = !conversationViewModel.conversation.value.isSwarm() ? transferInfo.fileName : self.message.daemonId
        guard let fileExtension = NSURL(fileURLWithPath: name).pathExtension else {
            return nil
        }
        if fileExtension.isMediaExtension() {
            if conversationViewModel.conversation.value.isSwarm() {
                let path = self.dataTransferService
                    .getFileUrlForSwarm(fileName: self.message.daemonId,
                                        accountID: conversationViewModel.conversation.value.accountId,
                                        conversationID: conversationViewModel.conversation.value.id)
                let pathString = path?.path ?? ""
                if pathString.isEmpty {
                    return nil
                }
                let model = PlayerViewModel(injectionBag: injectBug, path: pathString)
                conversationViewModel.setPlayer(messageID: String(self.messageId), player: model)
                return model
            }
            // first search for incoming video in downloads folder and for outgoing in recorded
            let folderName = self.message.incoming ? Directories.downloads.rawValue : Directories.recorded.rawValue
            var path = self.dataTransferService
                .getFileUrlNonSwarm(fileName: name,
                                    inFolder: folderName,
                                    accountID: conversationViewModel.conversation.value.accountId,
                                    conversationID: conversationViewModel.conversation.value.id)
            var pathString = path?.path ?? ""
            if pathString.isEmpty && self.message.incoming {
                return nil
            } else if pathString.isEmpty {
                // try to search outgoing video in downloads folder
                path = self.dataTransferService
                    .getFileUrlNonSwarm(fileName: name,
                                        inFolder: Directories.downloads.rawValue,
                                        accountID: conversationViewModel.conversation.value.accountId,
                                        conversationID: conversationViewModel.conversation.value.id)
                pathString = path?.path ?? ""
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
                            accountId: String,
                            isSwarm: Bool) -> URL? {
        guard let account = self.accountService
                .getAccount(fromAccountId: accountId) else { return nil }
        if self.message.incoming &&
            self.lastTransferStatus != .success &&
            self.message.transferStatus != .success {
            return nil
        }
        let transferInfo = transferFileData
        let name = isSwarm ? self.message.daemonId : transferInfo.fileName
        return self.dataTransferService
            .getFileUrlForSwarm(fileName: name, accountID: account.id, conversationID: conversationID)
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
