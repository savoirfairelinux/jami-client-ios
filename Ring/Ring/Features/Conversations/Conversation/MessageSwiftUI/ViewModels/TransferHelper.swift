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

enum TransferState: State {
    case accept(viewModel: MessageContentVM)
    case cancel(viewModel: MessageContentVM)
    case getProgress(viewModel: MessageContentVM)
    case getSize(viewModel: MessageContentVM)
    case getURL(viewModel: MessageContentVM)
    case getPlayer(viewModel: MessageContentVM)
}

class TransferHelper {
    let injectionBag: InjectionBag
    let dataTransferService: DataTransferService

    private var players = [String: PlayerViewModel]()

    func getPlayer(messageID: String) -> PlayerViewModel? {
        return players[messageID]
    }

    func setPlayer(messageID: String, player: PlayerViewModel) { players[messageID] = player }

    func closeAllPlayers() {
        let queue = DispatchQueue.global(qos: .default)
        queue.sync {
            self.players.values.forEach { (player) in
                player.closePlayer()
            }
            self.players.removeAll()
        }
    }

    init (injectionBag: InjectionBag) {
        self.dataTransferService = injectionBag.dataTransferService
        self.injectionBag = injectionBag
    }

    func acceptTransfer(conversation: ConversationModel, message: MessageModel) -> NSDataTransferError {
        var fileName = ""
        self.dataTransferService.downloadFile(withId: message.daemonId, interactionID: message.id, fileName: &fileName, accountID: conversation.accountId, conversationID: conversation.id)
        return .success
    }

    func cancelTransfer(conversation: ConversationModel, message: MessageModel) -> NSDataTransferError {
        return self.dataTransferService.cancelTransfer(withId: message.daemonId, accountId: conversation.accountId, conversationId: conversation.id)
    }

    func getTransferProgress(conversation: ConversationModel, message: MessageModel) -> Float? {
        let progress = self.dataTransferService.getTransferProgress(withId: message.daemonId, accountId: conversation.accountId, conversationId: conversation.id, isSwarm: conversation.isSwarm())
        return message.totalSize > 0 ? Float(progress) / Float(message.totalSize) : Float(progress)
    }

    func getTransferSize(conversation: ConversationModel, message: MessageModel) -> Int64? {
        guard let info = self.dataTransferService.dataTransferInfo(withId: message.daemonId,
                                                                   accountId: conversation.accountId,
                                                                   conversationId: conversation.id,
                                                                   isSwarm: conversation.isSwarm()) else { return nil }
        return info.totalSize
    }

    func getFileURL(conversation: ConversationModel, message: MessageModel) -> URL? {
        if message.transferStatus != .success {
            return nil
        }
        let transferInfo = self.getTransferFileData(content: message.content)
        if conversation.isSwarm() {
            return self.dataTransferService.getFileUrlForSwarm(fileName: message.daemonId, accountID: conversation.accountId, conversationID: conversation.id)
        }
        if message.incoming {
            return self.dataTransferService
                .getFileUrlNonSwarm(fileName: transferInfo.fileName,
                                    inFolder: Directories.downloads.rawValue,
                                    accountID: conversation.accountId,
                                    conversationID: conversation.id)
        }

        let recorded = self.dataTransferService
            .getFileUrlNonSwarm(fileName: transferInfo.fileName,
                                inFolder: Directories.recorded.rawValue,
                                accountID: conversation.accountId,
                                conversationID: conversation.id)
        guard recorded == nil, recorded?.path.isEmpty ?? true else { return recorded }
        return self.dataTransferService
            .getFileUrlNonSwarm(fileName: transferInfo.fileName,
                                inFolder: Directories.downloads.rawValue,
                                accountID: conversation.accountId,
                                conversationID: conversation.id)
    }

    func getPlayer(conversation: ConversationModel, message: MessageModel) -> PlayerViewModel? {
        if message.transferStatus != .success {
            return nil
        }

        if let playerModel = self.getPlayer(messageID: String(message.id)) {
            return playerModel
        }
        let transferInfo = self.getTransferFileData(content: message.content)
        let name = conversation.isSwarm() ? message.daemonId : transferInfo.fileName
        guard let fileExtension = NSURL(fileURLWithPath: name).pathExtension else {
            return nil
        }
        if fileExtension.isMediaExtension() {
            if conversation.isSwarm() {
                let path = self.dataTransferService
                    .getFileUrlForSwarm(fileName: message.daemonId,
                                        accountID: conversation.accountId,
                                        conversationID: conversation.id)
                let pathString = path?.path ?? ""
                if pathString.isEmpty {
                    return nil
                }
                let model = PlayerViewModel(injectionBag: self.injectionBag, path: pathString)
                self.setPlayer(messageID: String(message.id), player: model)
                return model
            }
            // first search for incoming video in downloads folder and for outgoing in recorded
            let folderName = message.incoming ? Directories.downloads.rawValue : Directories.recorded.rawValue
            var path = self.dataTransferService
                .getFileUrlNonSwarm(fileName: name,
                                    inFolder: folderName,
                                    accountID: conversation.accountId,
                                    conversationID: conversation.id)
            var pathString = path?.path ?? ""
            if pathString.isEmpty && message.incoming {
                return nil
            } else if pathString.isEmpty {
                // try to search outgoing video in downloads folder
                path = self.dataTransferService
                    .getFileUrlNonSwarm(fileName: name,
                                        inFolder: Directories.downloads.rawValue,
                                        accountID: conversation.accountId,
                                        conversationID: conversation.id)
                pathString = path?.path ?? ""
                if pathString.isEmpty {
                    return nil
                }
            }
            let model = PlayerViewModel(injectionBag: self.injectionBag, path: pathString)
            self.setPlayer(messageID: String(message.id), player: model)
            return model
        }
        return nil
    }

    typealias TransferParsingTuple = (fileName: String, fileSize: String?, identifier: String?)

    private func getTransferFileData(content: String) -> TransferParsingTuple {
        let contentArr = content.components(separatedBy: "\n")
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
}
