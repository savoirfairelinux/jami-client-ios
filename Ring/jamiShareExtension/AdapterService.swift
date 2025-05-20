/*
 *  Copyright (C) 2018-2019 Savoir-faire Linux Inc.
 *
 *  Author: Andreas Traczyk <andreas.traczyk@savoirfairelinux.com>
 *  Author: Quentin Muret <quentin.muret@savoirfairelinux.com>
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

import SwiftyBeaver
import RxSwift
import Foundation
import MobileCoreServices
import Photos

public final class AdapterService {

    private let log = SwiftyBeaver.self

    private let adapter: Adapter

    init(withAdapter Adapter: Adapter) {
        self.adapter = Adapter
    }

    func sendSwarmMessage(accountId: String, conversationId: String, message: String, parentId: String) {
        adapter.setAccountActive(accountId, active: true)
        adapter.sendSwarmMessage(accountId, conversationId: conversationId, message: message, parentId: parentId, flag: 0)
        log.info("*** Message sent ***")
    }

    func sendSwarmFile(accountId: String, conversationId: String, filePath: String, fileName: String, parentId: String) {
        let cleanedPath = filePath.replacingOccurrences(of: "file://", with: "")
        let fileManager = FileManager.default
        let tempDirectory = NSTemporaryDirectory()
        let duplicatedFilePath = (tempDirectory as NSString).appendingPathComponent(fileName)

        do {
            if fileManager.fileExists(atPath: duplicatedFilePath) {
                try fileManager.removeItem(atPath: duplicatedFilePath)
            }

            try fileManager.copyItem(atPath: cleanedPath, toPath: duplicatedFilePath)

            adapter.setAccountActive(accountId, active: true)
            adapter.sendSwarmFile(withName: fileName, accountId: accountId, conversationId: conversationId, withFilePath: duplicatedFilePath, parent: parentId)
            log.info("*** File duplicated and sent successfully ***")
        } catch {
            log.error("Error duplicating file: \(error.localizedDescription)")
        }
    }
    
    func getAccountList() -> [String] {
        return adapter.getAccountList() as? [String] ?? []
    }

    func getConversationsByAccount() -> [String: [String]] {
        var result: [String: [String]] = [:]
        for account in getAccountList() {
            let conversations = adapter.getSwarmConversations(forAccount: account) as? [String] ?? []
            result[account] = conversations
        }
        return result
    }

    
}
