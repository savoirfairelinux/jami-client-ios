import RxSwift
import RxRelay

// Interface for message handling
protocol MessageHandling: VCardSender {
    func sendTextMessage(callID: String, message: String, accountId: AccountModel)
    func sendChunk(callID: String, message: [String: String], accountId: String, from: String)
}

class MessageHandlingService: MessageHandling {
    private let callsAdapter: CallsAdapter
    private let dbManager: DBManager
    private let calls: BehaviorRelay<[String: CallModel]>
    private let newMessagesStream: PublishSubject<ServiceEvent>
    private let ringVCardMIMEType = "x-ring/ring.profile.vcard;"

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
        if accountID.isEmpty || callID.isEmpty {
            return
        }
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            guard let profile = self.dbManager.accountVCard(for: accountID) else { return }
            let jamiId = profile.uri
            VCardUtils.sendVCard(card: profile,
                                 callID: callID,
                                 accountID: accountID,
                                 sender: self, from: jamiId)
        }
    }

    func sendTextMessage(callID: String, message: String, accountId: AccountModel) {
        guard let call = self.calls.value[callID] else { return }
        let messageDictionary = ["text/plain": message]
        self.callsAdapter.sendTextMessage(withCallID: callID,
                                          accountId: accountId.id,
                                          message: messageDictionary,
                                          from: call.paricipantHash(),
                                          isMixed: true)
        let accountHelper = AccountModelHelper(withAccount: accountId)
        let type = accountHelper.isAccountSip() ? URIType.sip : URIType.ring
        let contactUri = JamiURI.init(schema: type, infoHash: call.participantUri, account: accountId)
        guard let stringUri = contactUri.uriString else {
            return
        }
        if let uri = accountHelper.uri {
            var event = ServiceEvent(withEventType: .newOutgoingMessage)
            event.addEventInput(.content, value: message)
            event.addEventInput(.peerUri, value: stringUri)
            event.addEventInput(.accountId, value: accountId.id)
            event.addEventInput(.accountUri, value: uri)

            self.newMessagesStream.onNext(event)
        }
    }

    func sendChunk(callID: String, message: [String: String], accountId: String, from: String) {
        self.callsAdapter.sendTextMessage(withCallID: callID,
                                          accountId: accountId,
                                          message: message,
                                          from: from,
                                          isMixed: true)
    }

    /// Handles an incoming message
    func handleIncomingMessage(callId: String, fromURI: String, message: [String: String]) {
        guard let call = self.calls.value[callId] else { return }
        if message.keys.filter({ $0.hasPrefix(self.ringVCardMIMEType) }).first != nil {
            var data = [String: Any]()
            data[ProfileNotificationsKeys.ringID.rawValue] = fromURI
            data[ProfileNotificationsKeys.accountId.rawValue] = call.accountId
            data[ProfileNotificationsKeys.message.rawValue] = message
            NotificationCenter.default.post(name: NSNotification.Name(ProfileNotifications.messageReceived.rawValue), object: nil, userInfo: data)
            return
        }
        let accountId = call.accountId
        let displayName = call.displayName
        let registeredName = call.registeredName
        let name = !displayName.isEmpty ? displayName : registeredName
        var event = ServiceEvent(withEventType: .newIncomingMessage)
        event.addEventInput(.content, value: message.values.first)
        event.addEventInput(.peerUri, value: fromURI.filterOutHost())
        event.addEventInput(.name, value: name)
        event.addEventInput(.accountId, value: accountId)
        self.newMessagesStream.onNext(event)
    }
}

