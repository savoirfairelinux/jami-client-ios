/*
 *  Copyright (C) 2016-2025 Savoir-faire Linux Inc.
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

/// A namespace for common helper functions shared across all targets: jami, share extension, notification extension.
enum CommonHelpers {
    static func createFileUrlForSwarm(fileName: String, accountId: String, conversationId: String) -> URL? {
        let fileNameOnly = (fileName as NSString).deletingPathExtension
        let fileExtensionOnly = (fileName as NSString).pathExtension
        guard let documentsURL = Constants.documentsPath else {
            return nil
        }
        let directoryURL = documentsURL.appendingPathComponent(accountId)
            .appendingPathComponent("conversation_data")
            .appendingPathComponent(conversationId)
        var isDirectory = ObjCBool(false)
        let directoryExists = FileManager.default.fileExists(atPath: directoryURL.path, isDirectory: &isDirectory)
        if directoryExists && isDirectory.boolValue {
            var finalFileName = fileNameOnly + "." + fileExtensionOnly
            var filePathCheck = directoryURL.appendingPathComponent(finalFileName)
            var fileExists = FileManager.default.fileExists(atPath: filePathCheck.path, isDirectory: &isDirectory)
            var duplicates = 2
            while fileExists {
                finalFileName = fileNameOnly + "_" + String(duplicates) + "." + fileExtensionOnly
                filePathCheck = directoryURL.appendingPathComponent(finalFileName)
                fileExists = FileManager.default.fileExists(atPath: filePathCheck.path, isDirectory: &isDirectory)
                duplicates += 1
            }
            return filePathCheck
        }
        return nil
    }

    static func setUpdatedConversations(accountId: String, conversationId: String) {
        guard let userDefaults = UserDefaults(suiteName: Constants.appGroupIdentifier) else {
            return
        }
        var conversationData = [[String: String]]()
        if let existingData = userDefaults.object(forKey: Constants.updatedConversations) as? [[String: String]] {
            conversationData = existingData
        }

        for data in conversationData
        where data[Constants.NotificationUserInfoKeys.accountID.rawValue] == accountId &&
            data[Constants.NotificationUserInfoKeys.conversationID.rawValue] == conversationId {
            return
        }

        let conversation = [
            Constants.NotificationUserInfoKeys.accountID.rawValue: accountId,
            Constants.NotificationUserInfoKeys.conversationID.rawValue: conversationId
        ]

        conversationData.append(conversation)
        userDefaults.set(conversationData as Any, forKey: Constants.updatedConversations)
    }
}

/**
 Represents the status of a username validation request when the user is typing his username
 */
enum UsernameValidationStatus {
    case empty
    case lookingUp
    case invalid
    case alreadyTaken
    case valid
}

enum DataTransferEvent: UInt32 {
    case invalid = 0
    case created
    case unsupported
    case waitPeerAcceptance
    case waitHostAcceptance
    case ongoing
    case finished
    case closedByHost
    case closedByPeer
    case invalidPathname
    case unjoinablePeer

    var description: String {
        switch self {
        case .invalid: return "Invalid transfer"
        case .created: return "Transfer created"
        case .unsupported: return "Transfer type unsupported"
        case .waitPeerAcceptance: return "Waiting for peer to accept"
        case .waitHostAcceptance: return "Waiting for host to accept"
        case .ongoing: return "Transfer in progress"
        case .finished: return "Transfer completed"
        case .closedByHost: return "Transfer closed by sender"
        case .closedByPeer: return "Transfer closed by receiver"
        case .invalidPathname: return "Transfer failed: Invalid file path"
        case .unjoinablePeer: return "Transfer failed: Peer unavailable"
        }
    }

    func isCompleted() -> Bool {
        switch self {
        case .finished, .closedByHost, .closedByPeer, .unjoinablePeer, .invalidPathname:
            return true
        default:
            return false
        }
    }
}

/**
 The different states that an account can have during time.

 Contains :
 - lifecycle account states
 - errors concerning the state of the accounts
 */
enum AccountState: String {
    case registered = "REGISTERED"
    case ready = "READY"
    case unregistered = "UNREGISTERED"
    case trying = "TRYING"
    case error = "ERROR"
    case errorGeneric = "ERROR_GENERIC"
    case errorAuth = "ERROR_AUTH"
    case errorNetwork = "ERROR_NETWORK"
    case errorHost = "ERROR_HOST"
    case errorConfStun = "ERROR_CONF_STUN"
    case errorExistStun = "ERROR_EXIST_STUN"
    case errorServiceUnavailable = "ERROR_SERVICE_UNAVAILABLE"
    case errorNotAcceptable = "ERROR_NOT_ACCEPTABLE"
    case errorRequestTimeout = "Request Timeout"
    case errorNeedMigration = "ERROR_NEED_MIGRATION"
    case initializing = "INITIALIZING"

    // check if error status
    func isError() -> Bool {
        return self == .error || self == .errorGeneric
            || self == .errorAuth || self == .errorHost
            || self == .errorConfStun || self == .errorExistStun
            || self == .errorServiceUnavailable || self == .errorNotAcceptable
            || self == .errorRequestTimeout || self == .errorNeedMigration
            || self == .errorNetwork
    }

    // check if network error status
    func isNetworkError() -> Bool {
        return self == .errorNetwork
    }
}
