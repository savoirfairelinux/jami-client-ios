//
//  ShareConversationModel.swift
//  Ring
//
//  Created by Alireza Toghiani on 7/26/23.
//  Copyright © 2023 Savoir-faire Linux. All rights reserved.
//

import UIKit

/**
 Errors that can be thrown when trying to build an AccountModel
 */
enum AccountModelError: Error {
    case unexpectedError
}

struct JamsUserSearchModel {
    var username, firstName, lastName, organization, jamiId: String
    var profilePicture: Data?
}

enum ConversationType: Int {
    case oneToOne
    case adminInvitesOnly
    case invitesOnly
    case publicChat
    case nonSwarm
    case sip
    case jams

    var stringValue: String {
        switch self {
        case .oneToOne:
            return L10n.Swarm.oneToOne
        case .adminInvitesOnly:
            return L10n.Swarm.adminInvitesOnly
        case .invitesOnly:
            return L10n.Swarm.invitesOnly
        case .publicChat:
            return L10n.Swarm.publicChat
        default:
            return L10n.Swarm.others
        }
    }
}

enum ConversationMemberEvent: Int {
    case add
    case joins
    case leave
    case banned
}

enum FileTransferType: Int {
    case audio
    case video
    case image
    case gif
    case unknown
}
enum ConversationSchema: Int {
    case jami
    case swarm
}

enum ConversationAttributes: String {
    case title = "title"
    case description = "description"
    case avatar = "avatar"
    case mode = "mode"
    case conversationId = "id"
}

enum ConversationPreferenceAttributes: String {
    case color
    case ignoreNotifications
}

enum ParticipantRole: String {
    case invited
    case admin
    case member
    case banned
    case unknown

    var stringValue: String {
        switch self {
        case .member:
            return L10n.Swarm.member
        case .invited:
            return L10n.Swarm.invited
        case .admin:
            return L10n.Swarm.admin
        case .banned:
            return L10n.Swarm.banned
        case .unknown:
            return L10n.Swarm.unknown
        }
    }
}

struct ConversationPreferences {
    var color: String = UIColor.defaultSwarm
    var ignoreNotifications: Bool = false

    mutating func update(info: [String: String]) {
        if let color = info[ConversationPreferenceAttributes.color.rawValue] {
            self.color = color
        }
        if let ignoreNotifications = info[ConversationPreferenceAttributes.ignoreNotifications.rawValue] {
            self.ignoreNotifications = (ignoreNotifications as NSString).boolValue
        }
    }
}

enum URIType {
    case ring
    case sip

    func getString() -> String {
        switch self {
        case .ring:
            return "ring"
        case .sip:
            return "sip"
        }
    }
}

// swiftlint:disable identifier_name

enum DataTransferServiceError: Error {
    case createTransferError
    case updateTransferError
}

enum Directories: String {
    case recorded
    case downloads
    case conversation_data
}

enum DataTransferStatus: CustomStringConvertible {
    var description: String {
        switch self {
        case .created: return ""
        case .awaiting: return ""
        case .canceled: return "Canceled"
        case .ongoing: return "Transferring"
        case .success: return "Completed"
        case .error: return ""
        case .unknown: return ""
        }
    }

    case created
    case awaiting
    case canceled
    case ongoing
    case success
    case error
    case unknown
}

// MARK: - Message Model

enum MessageAttributes: String {
    case interactionId = "id"
    case type = "type"
    case invited = "invited"
    case fileId = "fileId"
    case displayName = "displayName"
    case body = "body"
    case author = "author"
    case uri = "uri"
    case timestamp = "timestamp"
    case parent = "linearizedParent"
    case action = "action"
    case duration = "duration"
    case reply = "reply-to"
    case react = "react-to"
    case totalSize = "totalSize"
}

enum MessageType: String {
    case text = "text/plain"
    case fileTransfer = "application/data-transfer+json"
    case contact = "member"
    case call = "application/call-history+json"
    case merge = "merge"
    case initial = "initial"
    case profile = "application/update-profile"
}

enum ContactAction: String {
    case add
    case remove
    case join
    case banned
    case unban
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

let registeredNamesKey = "REGISTERED_NAMES_KEY"

// MARK: - DBManager

enum DBBridgingError: Error {
    case saveMessageFailed
    case getConversationFailed
    case updateIntercationFailed
    case deleteConversationFailed
    case getProfileFailed
    case deleteMessageFailed
}

enum InteractionType: String {
    case invalid    = "INVALID"
    case text       = "TEXT"
    case call       = "CALL"
    case contact    = "CONTACT"
    case iTransfer  = "INCOMING_DATA_TRANSFER"
    case oTransfer  = "OUTGOING_DATA_TRANSFER"

    func toMessageType() -> MessageType {
        switch self {
        case .invalid, .text:
            return .text
        case .call:
            return .call
        case .contact:
            return .contact
        case .iTransfer:
            return .fileTransfer
        case .oTransfer:
            return .fileTransfer
        }
    }
}

enum GeneratedMessageType: String {
    case receivedContactRequest = "Contact request received"
    case contactAdded = "Contact added"
    case missedIncomingCall = "Missed incoming call"
    case missedOutgoingCall = "Missed outgoing call"
    case incomingCall = "Incoming call"
    case outgoingCall = "Outgoing call"
}

enum GeneratedMessage: Int {
    case outgoingCall
    case incomingCall
    case missedOutgoingCall
    case missedIncomingCall
    case contactAdded
    case invitationReceived
    case invitationAccepted
    case unknown

    func toString() -> String {
        return String(self.rawValue)
    }
    init(from: String) {
        if let intValue = Int(from) {
            self = GeneratedMessage(rawValue: intValue) ?? .unknown
        } else {
            self = .unknown
        }
    }
    func toMessage(with duration: Int) -> String {
        let time = Date.convertSecondsToTimeString(seconds: Double(duration))
        switch self {
        case .contactAdded:
            return L10n.GeneratedMessage.contactAdded
        case .invitationReceived:
            return L10n.GeneratedMessage.invitationReceived
        case .invitationAccepted:
            return L10n.GeneratedMessage.invitationAccepted
        case .missedOutgoingCall:
            return L10n.GeneratedMessage.missedOutgoingCall
        case .missedIncomingCall:
            return L10n.GeneratedMessage.missedIncomingCall
        case .outgoingCall:
            return L10n.GeneratedMessage.outgoingCall + " - " + time
        case .incomingCall:
            return L10n.Global.incomingCall + " - " + time
        default:
            return ""
        }
    }
}
