import RxSwift
import Combine

class ShareViewModel: ObservableObject {
    @Published var fileTransferStatus: String = ""
    @Published var accountList: [String] = []
    @Published var conversationsByAccount: [String: [String]] = [:]
    @Published var newStatusIndicators: [String: NewStatusIndicator] = [:]

    struct NewStatusIndicator {
        enum ItemType {
            case text
            case file
        }

        var type: ItemType
        var itemIdentifier: String
        var convid: String
        var accountid: String
        var messageid: String? = nil
        var itemstatus: String = "Pending"
        
        // Unique key generator for storage
        static func makeKey(accountId: String, convid: String, itemIdentifier: String) -> String {
            return "\(accountId)|\(convid)|\(itemIdentifier)"
        }
    }

    private let disposeBag = DisposeBag()
    private var sendFileDisposeBag = DisposeBag() // For sendFile-specific subscriptions

    private var adapter: Adapter
    private var adapterService: AdapterService

    // Track ongoing transfer IDs (Strings) per account
    private var ongoingTransfersByAccount: [String: Set<String>] = [:]

    init(sharedItems: [NSExtensionItem]) {
        self.adapter = Adapter()
        self.adapter.initDaemon()
        self.adapter.startDaemon()
        self.adapterService = AdapterService(withAdapter: adapter)

        subscribeToFileTransferStatus()
        subscribeToNewInteractions()
        subscribeToMessageStatusChanged()
        fetchAccountsAndConversations()
    }

    private func subscribeToFileTransferStatus() {
        adapterService.newInteractionStream
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] event in
                guard let self = self else { return }
                
                let interaction = event.interaction
                
                // Search through newStatusIndicators for a match
                for (key, indicator) in self.newStatusIndicators {
                    var matched = false
                    
                    switch indicator.type {
                    case .text:
                        if let bodyText = interaction.body["body"] as? String,
                           bodyText.trimmingCharacters(in: .whitespacesAndNewlines) == indicator.itemIdentifier {
                            matched = true
                        }
                    case .file:
                        if let displayName = interaction.body["displayName"] as? String,
                           displayName == indicator.itemIdentifier {
                            matched = true
                        }
                    }
                    
                    if matched {
                        // Update the messageid for that indicator
                        var updatedIndicator = indicator
                        updatedIndicator.messageid = interaction.messageId
                        self.newStatusIndicators[key] = updatedIndicator
                        
                        print("Messageid found for \(indicator.itemIdentifier): \(interaction.messageId ?? "nil")")
                        
                        break // Assuming one match per interaction event
                    }
                }
                
                // Existing debug prints...
            })
            .disposed(by: disposeBag)
    }

    private func subscribeToNewInteractions() {
        adapterService.newInteractionStream
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] event in
                let interaction = event.interaction
                print("📬 New interaction received:")
                print("  - Account ID: \(interaction.accountId)")
                print("  - Conversation ID: \(interaction.conversationId)")
                print("  - Message ID: \(interaction.messageId)")
                print("  - Type: \(interaction.type)")
                print("  - Parent: \(interaction.parent ?? "nil")")
                print("  - Body: \(interaction.body)")
                print("  - Reactions: \(interaction.reactions)")
                print("  - Editions: \(interaction.editions)")
//                print("  - Status: \(interaction.status)")
            })
            .disposed(by: disposeBag)
    }
    
    private func subscribeToMessageStatusChanged() {
        adapterService.messageStatusChangedStream
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] event in
                guard let self = self else { return }

                for (key, indicator) in self.newStatusIndicators {
                    guard indicator.accountid == event.accountId,
                          indicator.convid == event.conversationId,
                          let msgId = indicator.messageid,
                          msgId == event.messageId else {
                        continue
                    }

                    let statusEnum = ShareMessageStatus(rawValue: Int(event.status.rawValue))

                    let statusDescription = statusEnum?.description ?? "Unknown status"

                    print("📩 Status update for message \(msgId): \(statusDescription) (\(event.status))")

                    var updated = indicator
                    updated.itemstatus = statusDescription
                    self.newStatusIndicators[key] = updated
                }
            })
            .disposed(by: disposeBag)
    }

    private func fetchAccountsAndConversations() {
        accountList = adapterService.getAccountList()
        var convsByAccount = adapterService.getConversationsByAccount()

        for accountId in accountList {
            let conversations = adapter.getSwarmConversations(forAccount: accountId) as? [String] ?? []
            convsByAccount[accountId] = conversations
        }

        conversationsByAccount = convsByAccount
    }

    
    func sendMessage(accountId: String, conversationId: String, message: String, parentId: String? = nil) {
        let key = NewStatusIndicator.makeKey(accountId: accountId, convid: conversationId, itemIdentifier: message)
        newStatusIndicators[key] = NewStatusIndicator(
            type: .text,
            itemIdentifier: message,
            convid: conversationId,
            accountid: accountId,
            messageid: nil,
            itemstatus: "Pending"
        )
        
        adapterService.sendSwarmMessage(
            accountId: accountId,
            conversationId: conversationId,
            message: message,
            parentId: parentId ?? ""
        )
    }

    func sendFile(accountId: String, conversationId: String, filePath: String, fileName: String, parentId: String? = nil) {
        let key = NewStatusIndicator.makeKey(accountId: accountId, convid: conversationId, itemIdentifier: fileName)
        newStatusIndicators[key] = NewStatusIndicator(
            type: .file,
            itemIdentifier: fileName,
            convid: conversationId,
            accountid: accountId,
            messageid: nil,
            itemstatus: "Pending"
        )
        
        adapterService.setAccountActive(accountId, newValue: true)
        
        adapterService.sendSwarmFile(
            accountId: accountId,
            conversationId: conversationId,
            filePath: filePath,
            fileName: fileName,
            parentId: parentId ?? ""
        )

        // Clear previous subscriptions to avoid duplicates
        sendFileDisposeBag = DisposeBag()

        adapterService.fileTransferStatusStream
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] status in
                guard let self = self,
                      let event = DataTransferEvent(rawValue: UInt32(status.eventCode)) else { return }

                let transferId = status.transferId // String
                var activeTransfers = self.ongoingTransfersByAccount[accountId] ?? Set<String>()

                switch event {
                case .created:
                    // Add transferId to active set
                    activeTransfers.insert(transferId)
                    self.ongoingTransfersByAccount[accountId] = activeTransfers

                case .finished, .closedByHost, .closedByPeer, .invalidPathname, .unjoinablePeer:
                    // Remove transferId from active set
                    activeTransfers.remove(transferId)
                    self.ongoingTransfersByAccount[accountId] = activeTransfers

                    // Update conversations regardless of success/failure
                    self.adapterService.setUpdatedConversations(accountId: accountId, conversationId: conversationId)

                    // If no more active transfers, set account inactive
                    if activeTransfers.isEmpty {
                        self.adapterService.setAccountActive(accountId, newValue: false)
                    }

                default:
                    // For other statuses, update conversations only
                    self.adapterService.setUpdatedConversations(accountId: accountId, conversationId: conversationId)
                }
            })
            .disposed(by: sendFileDisposeBag)
    }
}

extension Notification.Name {
    static let fileTransferStatusUpdated = Notification.Name("fileTransferStatusUpdated")
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
        case .invalid:
            return "Invalid transfer"
        case .created:
            return "Transfer created"
        case .unsupported:
            return "Transfer type unsupported"
        case .waitPeerAcceptance:
            return "Waiting for peer to accept"
        case .waitHostAcceptance:
            return "Waiting for host to accept"
        case .ongoing:
            return "Transfer in progress"
        case .finished:
            return "Transfer completed"
        case .closedByHost:
            return "Transfer closed by sender"
        case .closedByPeer:
            return "Transfer closed by receiver"
        case .invalidPathname:
            return "Transfer failed: Invalid file path"
        case .unjoinablePeer:
            return "Transfer failed: Peer unavailable"
        }
    }
    

}

enum ShareMessageStatus: Int {
    case statusUnknown = 0
    case sending = 1
    case sent = 2
    case displayed = 3
    case failure = 4
    case canceled = 5

    var description: String {
        switch self {
        case .statusUnknown: return "Unknown status"
        case .sending: return "Sending"
        case .sent: return "Sent"
        case .displayed: return "Displayed"
        case .failure: return "Failed to send"
        case .canceled: return "Canceled"
        }
    }
}
