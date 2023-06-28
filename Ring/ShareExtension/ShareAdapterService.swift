/*
 *  Copyright (C) 2021-2022 Savoir-faire Linux Inc.
 *
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
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
import UIKit
import MobileCoreServices
import Photos
import os

class ShareAdapterService {
    enum InteractionAttributes: String {
        case interactionId = "id"
        case type = "type"
        case invited = "invited"
        case fileId = "fileId"
        case displayName = "displayName"
        case body = "body"
        case author = "author"
        case timestamp = "timestamp"
        case parent = "linearizedParent"
        case action = "action"
        case duration = "duration"
    }

    enum InteractionType: String {
        case message = "text/plain"
        case fileTransfer = "application/data-transfer+json"
    }

    enum EventType: Int {
        case message
        case fileTransferDone
        case fileTransferInProgress
        case syncCompleted
        case conversationCloned
        case invitation
    }

    enum PeerConnectionRequestType {
        case call(peerId: String, isVideo: Bool)
        case gitMessage
        case clone
        case unknown
    }

    enum DataTransferEventCode: Int {
        case invalid
        case created
        case unsupported
        case waitPeeracceptance
        case waitHostAcceptance
        case ongoing
        case finished
        case closedByHost
        case closedByPeer
        case invalidPathname
        case unjoinablePeer

        func isCompleted() -> Bool {
            switch self {
            case .finished, .closedByHost, .closedByPeer, .unjoinablePeer, .invalidPathname:
                return true
            default:
                return false
            }
        }
    }

    private let maxSizeForAutoaccept = 20 * 1024 * 1024

    private var adapter: ShareAdapter!
    var eventHandler: ((String, Data) -> Void)?
    //    var loadingFiles = [String: EventData]()

    init(withAdapter adapter: ShareAdapter) {
        self.adapter = adapter
        ShareAdapter.delegate = self
    }

    func startAccountsWithListener(accountId: String, listener: @escaping (String, Data) -> Void) {
        self.eventHandler = listener
        start(accountId: accountId)
    }

    func start(accountId: String) {
        self.adapter.start(accountId)
    }

    func removeDelegate() {
        ShareAdapter.delegate = nil
        self.adapter = nil
    }

    func stop() {
        self.adapter.stop()
        removeDelegate()
    }

    //    func getNameFor(address: String, accountId: String) -> String {
    //        return adapter.getNameFor(address, accountId: accountId)
    //    }
    //
    //    func getNameServerFor(accountId: String) -> String {
    //        return adapter.nameServer(forAccountId: accountId)
    //    }
}

extension ShareAdapterService: ShareAdapterDelegate {

}
