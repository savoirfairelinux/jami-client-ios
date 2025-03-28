/*
 *  Copyright (C) 2017-2025 Savoir-faire Linux Inc.
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
import RxRelay

/*
 * MessageHandlingService Thread Safety Contract:
 *
 * This service primarily deals with I/O operations and does not maintain mutable
 * state requiring synchronization. All operations use BehaviorRelay for thread-safe
 * access to calls data:
 *
 * 1. Read operations on BehaviorRelay:
 *    - All methods directly access calls.value
 *    - No queue synchronization needed as BehaviorRelay is thread-safe for reading
 *
 * 2. This service does not require a shared dispatch queue as it only performs
 *    read operations and delegates any write operations to external components.
 *
 * Note: This service follows the reactive pattern where state changes are observed
 * rather than directly modified.
 */

// MARK: - Protocol Definitions

protocol MessageHandling: VCardSender {
    func sendInCallMessage(callID: String, message: String, accountId: AccountModel)
    func handleIncomingMessage(callId: String, fromURI: String, message: [String: String])
    func sendChunk(callID: String, message: [String: String], accountId: String, from: String)
}

// MARK: - MessageHandlingService

/// Service responsible for handling messages during calls
final class MessageHandlingService: MessageHandling {
    
    // MARK: - Private Constants
    
    private enum Constants {
        static let ringVCardMIMETypePrefix = "x-ring/ring.profile.vcard;"
        static let messagePrefix = "text/plain"
    }
    
    // MARK: - Dependencies
    
    private let callsAdapter: CallsAdapter
    private let dbManager: DBManager
    private let calls: BehaviorRelay<[String: CallModel]>
    private let newMessagesStream: PublishSubject<ServiceEvent>
    
    // MARK: - Initialization
    
    /// Initialize the message handling service
    /// - Parameters:
    ///   - callsAdapter: The adapter for interacting with the native call service
    ///   - dbManager: The database manager
    ///   - calls: The behavior relay containing all calls
    ///   - newMessagesStream: The stream for new messages
    init(
        callsAdapter: CallsAdapter,
        dbManager: DBManager,
        calls: BehaviorRelay<[String: CallModel]>,
        newMessagesStream: PublishSubject<ServiceEvent>
    ) {
        self.callsAdapter = callsAdapter
        self.dbManager = dbManager
        self.calls = calls
        self.newMessagesStream = newMessagesStream
    }
    
    // MARK: - VCardSender Protocol Implementation
    
    /// Sends a vCard for the specified account
    /// - Parameters:
    ///   - callID: The call ID
    ///   - accountID: The account ID
    func sendVCard(callID: String, accountID: String) {
        guard !accountID.isEmpty, !callID.isEmpty else { return }
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self, 
                  let profile = self.dbManager.accountVCard(for: accountID) else { return }
            
            let jamiId = profile.uri
            VCardUtils.sendVCard(card: profile,
                               callID: callID,
                               accountID: accountID,
                               sender: self, 
                               from: jamiId)
        }
    }
    
    // MARK: - MessageHandling Protocol Implementation
    
    /// Sends a message during a call
    /// - Parameters:
    ///   - callID: The call ID
    ///   - message: The message to send
    ///   - accountId: The account sending the message
    func sendInCallMessage(callID: String, message: String, accountId: AccountModel) {
        // BehaviorRelay's value property is thread-safe for reading
        guard let call = calls.value[callID] else { return }
        
        let messageDictionary = [Constants.messagePrefix: message]
        callsAdapter.sendTextMessage(withCallID: callID,
                                   accountId: accountId.id,
                                   message: messageDictionary,
                                   from: call.paricipantHash(),
                                   isMixed: true)
        
        notifyOutgoingMessage(message: message, call: call, accountId: accountId)
    }
    
    /// Sends a chunk of a message
    /// - Parameters:
    ///   - callID: The call ID
    ///   - message: The message chunk
    ///   - accountId: The account ID
    ///   - from: The sender ID
    func sendChunk(callID: String, message: [String: String], accountId: String, from: String) {
        callsAdapter.sendTextMessage(withCallID: callID,
                                   accountId: accountId,
                                   message: message,
                                   from: from,
                                   isMixed: true)
    }
    
    // MARK: - Message Handling
    
    /// Handles an incoming message
    /// - Parameters:
    ///   - callId: The call ID
    ///   - fromURI: The sender URI
    ///   - message: The message content
    func handleIncomingMessage(callId: String, fromURI: String, message: [String: String]) {
        // BehaviorRelay's value property is thread-safe for reading
        guard let call = calls.value[callId] else { return }
        
        if isVCardMessage(message) {
            handleVCardMessage(fromURI: fromURI, call: call, message: message)
            return
        }
        
        notifyIncomingMessage(fromURI: fromURI, call: call, messageContent: message.values.first)
    }
    
    // MARK: - Private Helpers
    
    /// Checks if a message is a vCard message
    /// - Parameter message: The message to check
    /// - Returns: true if the message is a vCard message, false otherwise
    private func isVCardMessage(_ message: [String: String]) -> Bool {
        return message.keys.contains { $0.hasPrefix(Constants.ringVCardMIMETypePrefix) }
    }
    
    /// Handles a vCard message
    /// - Parameters:
    ///   - fromURI: The sender URI
    ///   - call: The call
    ///   - message: The vCard message
    private func handleVCardMessage(fromURI: String, call: CallModel, message: [String: String]) {
        var data = [String: Any]()
        data[ProfileNotificationsKeys.ringID.rawValue] = fromURI
        data[ProfileNotificationsKeys.accountId.rawValue] = call.accountId
        data[ProfileNotificationsKeys.message.rawValue] = message
        
        NotificationCenter.default.post(
            name: NSNotification.Name(ProfileNotifications.messageReceived.rawValue),
            object: nil,
            userInfo: data
        )
    }
    
    /// Notifies about an outgoing message
    /// - Parameters:
    ///   - message: The message content
    ///   - call: The call
    ///   - accountId: The account sending the message
    private func notifyOutgoingMessage(message: String, call: CallModel, accountId: AccountModel) {
        let accountHelper = AccountModelHelper(withAccount: accountId)
        let type = accountHelper.isAccountSip() ? URIType.sip : URIType.ring
        
        let contactUri = JamiURI(schema: type, infoHash: call.participantUri, account: accountId)
        guard let stringUri = contactUri.uriString, let uri = accountHelper.uri else { return }
        
        var event = ServiceEvent(withEventType: .newOutgoingMessage)
        event.addEventInput(.content, value: message)
        event.addEventInput(.peerUri, value: stringUri)
        event.addEventInput(.accountId, value: accountId.id)
        event.addEventInput(.accountUri, value: uri)
        
        newMessagesStream.onNext(event)
    }
    
    /// Notifies about an incoming message
    /// - Parameters:
    ///   - fromURI: The sender URI
    ///   - call: The call
    ///   - messageContent: The message content
    private func notifyIncomingMessage(fromURI: String, call: CallModel, messageContent: String?) {
        let accountId = call.accountId
        let displayName = call.displayName
        let registeredName = call.registeredName
        let name = !displayName.isEmpty ? displayName : registeredName
        
        var event = ServiceEvent(withEventType: .newIncomingMessage)
        event.addEventInput(.content, value: messageContent)
        event.addEventInput(.peerUri, value: fromURI.filterOutHost())
        event.addEventInput(.name, value: name)
        event.addEventInput(.accountId, value: accountId)
        
        newMessagesStream.onNext(event)
    }
}
