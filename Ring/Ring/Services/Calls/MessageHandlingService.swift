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


protocol MessageHandling: VCardSender {
    func sendInCallMessage(callID: String, message: String, accountId: AccountModel)
    func handleIncomingMessage(callId: String, fromURI: String, message: [String: String])
    func sendChunk(callID: String, message: [String: String], accountId: String, from: String)
}

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

    func sendInCallMessage(callID: String, message: String, accountId: AccountModel) {
        guard let call = calls.value[callID] else { return }
        
        let messageDictionary = [Constants.messagePrefix: message]
        callsAdapter.sendTextMessage(withCallID: callID,
                                   accountId: accountId.id,
                                   message: messageDictionary,
                                   from: call.paricipantHash(),
                                   isMixed: true)
        
        notifyOutgoingMessage(message: message, call: call, accountId: accountId)
    }

    func sendChunk(callID: String, message: [String: String], accountId: String, from: String) {
        callsAdapter.sendTextMessage(withCallID: callID,
                                   accountId: accountId,
                                   message: message,
                                   from: from,
                                   isMixed: true)
    }

    func handleIncomingMessage(callId: String, fromURI: String, message: [String: String]) {
        guard let call = calls.value[callId] else { return }
        
        if isVCardMessage(message) {
            handleVCardMessage(fromURI: fromURI, call: call, message: message)
            return
        }
        
        notifyIncomingMessage(fromURI: fromURI, call: call, messageContent: message.values.first)
    }

    private func isVCardMessage(_ message: [String: String]) -> Bool {
        return message.keys.contains { $0.hasPrefix(Constants.ringVCardMIMETypePrefix) }
    }

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
