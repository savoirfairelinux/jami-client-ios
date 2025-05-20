import RxSwift
import Combine

class ShareViewModel: ObservableObject {
    private let disposeBag = DisposeBag()
    private var adapter: Adapter
    private var adapterService: AdapterService
    private var ongoingTransfersByAccount: [String: Set<String>] = [:]
    private var stallTimer: Timer?
    private var didSetTransmissionSummary = false

    @Published var accountList: [(id: String, name: String)] = []
    @Published var conversationsByAccount: [String: [String]] = [:]
    @Published var transmissionSummary: String = ""
    @Published var transmissionStatus: [String: NewStatusIndicator] = [:]

    init(sharedItems: [NSExtensionItem]) {
        self.adapter = Adapter()
        self.adapter.initDaemon()
        self.adapter.startDaemon()
        self.adapterService = AdapterService(withAdapter: adapter)

        // Load accounts and conversations for UI
        fetchAccountsAndConversations()
        
        print("=====ZZZ")
        print(accountList)
        adapterService.printConversationInfo(accountId: "0494d8100c2d880d", conversationId: "7875de6c397bdf503592c99c7809f915da6c15cc")

        // Getting IDs used to track text and messages
        subscribeToNewInteractions()
        
        // Tracking text and file status
        subscribeToFileTransferStatus()
        subscribeToMessageStatusChanged()

        // Track transfers time-out
        startStallMonitoring()
    }

    // STEP 1: Get proper IDs for each transmission
    
    private func subscribeToNewInteractions() {
        adapterService.newInteractionStream
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] event in
                guard let self = self else { return }

                let interaction = event.interaction

                for (key, indicator) in self.transmissionStatus {
                    var matched = false
                    var messageIdToAssign: String? = nil
                    var transferIdToAssign: String? = nil

                    switch indicator.type {
                    case .text:
                        if let bodyText = interaction.body["body"] as? String,
                           bodyText.trimmingCharacters(in: .whitespacesAndNewlines) == indicator.itemIdentifier {
                            matched = true
                            messageIdToAssign = interaction.messageId
                        }
                    case .file:
                        if let displayName = interaction.body["displayName"] as? String,
                           displayName == indicator.itemIdentifier,
                           let messageId = interaction.body["id"] as? String, let fileId = interaction.body["fileId"] as? String {
                            matched = true
                            messageIdToAssign = messageId
                            transferIdToAssign = fileId
                        }
                    }

                    if let messageId = messageIdToAssign {
                        var updatedIndicator = indicator
                        updatedIndicator.messageid = messageId
                        updatedIndicator.transferId = transferIdToAssign ?? updatedIndicator.transferId
                        updatedIndicator.lastUpdate = Date()
                        self.transmissionStatus[key] = updatedIndicator
                        break
                    }
                }
            })
            .disposed(by: disposeBag)
    }

    private func subscribeToFileTransferStatus() {
        adapterService.fileTransferStatusStream
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] status in
                guard let self = self,
                      let event = DataTransferEvent(rawValue: UInt32(status.eventCode)) else { return }

                let transferId = status.transferId
                let interactionId = status.interactionId

                // Find the matching NewStatusIndicator key using messageid == interactionId for file type
                if let key = self.transmissionStatus.first(where: {
                    $0.value.type == .file &&
                    $0.value.messageid == interactionId
                })?.key {
                    
                    var updated = self.transmissionStatus[key]!
                    
                    // Map DataTransferEvent to TransmissionStatus
                    switch event {
                    case .created, .waitPeerAcceptance, .waitHostAcceptance, .ongoing:
                        updated.itemstatus = .ongoing
                    case .finished:
                        updated.itemstatus = .sent
                    case .invalid, .unsupported, .closedByHost, .closedByPeer, .invalidPathname, .unjoinablePeer:
                        updated.itemstatus = .failed
                    default:
                        break
                    }

                    updated.lastUpdate = Date()
                    self.transmissionStatus[key] = updated

                    // Manage ongoingTransfersByAccount state
                    let accountId = updated.accountid
                    var activeTransfers = self.ongoingTransfersByAccount[accountId] ?? Set<String>()

                    switch event {
                    case .created:
                        activeTransfers.insert(transferId)
                        self.ongoingTransfersByAccount[accountId] = activeTransfers
                    case .finished, .closedByHost, .closedByPeer, .invalidPathname, .unjoinablePeer:
                        activeTransfers.remove(transferId)
                        self.ongoingTransfersByAccount[accountId] = activeTransfers
                        if activeTransfers.isEmpty {
                            self.adapterService.setAccountActive(accountId, newValue: false)
                        }
                    default:
                        break
                    }

                    self.checkAllItemsSent()
                }
            })
            .disposed(by: disposeBag)
    }

    private func subscribeToMessageStatusChanged() {
        adapterService.messageStatusChangedStream
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] event in
                guard let self = self else { return }

                let interactionId = event.messageId
                let accountId = event.accountId
                let conversationId = event.conversationId
                let rawStatus = Int(event.status.rawValue)
                
                guard let msgStatus = ShareMessageStatus(rawValue: rawStatus) else { return }

                if let key = self.transmissionStatus.first(where: {
                    $0.value.type == .text &&
                    $0.value.accountid == accountId &&
                    $0.value.convid == conversationId &&
                    $0.value.messageid == interactionId
                })?.key {

                    var updated = self.transmissionStatus[key]!

                    switch msgStatus {
                    case .sending:
                        updated.itemstatus = .ongoing
                    case .sent, .displayed:
                        updated.itemstatus = .sent
                    case .failure, .canceled:
                        updated.itemstatus = .failed
                    case .statusUnknown:
                        break
                    }

                    updated.lastUpdate = Date()
                    self.transmissionStatus[key] = updated
                    self.checkAllItemsSent()
                } else {
                    print("❌ No matching indicator for text message status update with ID: \(interactionId): \(msgStatus)")
                }
            })
            .disposed(by: disposeBag)
    }

    private func fetchAccountsAndConversations() {
        let accountIds = adapterService.getAccountList()

        guard !accountIds.isEmpty else {
            print("**** No account IDs found ****")
            return
        }

        var convsByAccount = adapterService.getConversationsByAccount()

        let singles: [Single<[String: String]>] = accountIds.map { accountId in
            let conversations = adapter.getSwarmConversations(forAccount: accountId) as? [String] ?? []
            convsByAccount[accountId] = conversations

            return adapterService.resolveLocalAccountDetails(accountId: accountId)
                .do(onSuccess: { details in
                    print("======WZ: Resolved details for \(accountId): \(details)")
                    if let accountId = details["accountId"], let accountName = details["accountName"] {
                        self.accountList.append((id: accountId, name: accountName))
                    }
                }, onError: { error in
                    print("======WZ: Error resolving details for \(accountId): \(error)")
                })
        }

        self.conversationsByAccount = convsByAccount
    }

    func sendMessage(accountId: String, conversationId: String, message: String, parentId: String? = nil) {
        let key = NewStatusIndicator.makeKey(accountId: accountId, convid: conversationId, itemIdentifier: message)
        transmissionStatus[key] = NewStatusIndicator(
            type: .text,
            itemIdentifier: message,
            convid: conversationId,
            accountid: accountId,
            itemstatus: .ongoing,
            lastUpdate: Date()
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
        transmissionStatus[key] = NewStatusIndicator(
            type: .file,
            itemIdentifier: fileName,
            convid: conversationId,
            accountid: accountId,
            itemstatus: .ongoing,
            lastUpdate: Date()
        )

        adapterService.setAccountActive(accountId, newValue: true)

        adapterService.sendSwarmFile(
            accountId: accountId,
            conversationId: conversationId,
            filePath: filePath,
            fileName: fileName,
            parentId: parentId ?? ""
        )
    }

    private func checkAllItemsSent() {
        let indicators = transmissionStatus.values

        let allFinal = indicators.allSatisfy {
            $0.itemstatus == .sent || $0.itemstatus == .failed || $0.itemstatus == .stalled
        }

        if allFinal {
            didSetTransmissionSummary = true  // Prevent further executions

            let sentCount = indicators.filter { $0.itemstatus == .sent }.count
            let failedCount = indicators.filter { $0.itemstatus == .failed }.count
            let stalledCount = indicators.filter { $0.itemstatus == .stalled }.count

            transmissionSummary = """
            ✅ All items finalized. Summary:
               🟢 Sent: \(sentCount)
               🟡 Stalled: \(stalledCount)
               🔴 Failed: \(failedCount)
            """

            if let first = indicators.first {
                self.adapterService.setUpdatedConversations(accountId: first.accountid, conversationId: first.convid)
            }

            closeShareExtension()
        }
    }

    private func startStallMonitoring() {
        stallTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let now = Date()
            var updatedAny = false

            for (key, indicator) in self.transmissionStatus {
                // Stall detection still only applies to .ongoing
                if indicator.itemstatus == .ongoing, now.timeIntervalSince(indicator.lastUpdate) > 15 {
                    var stalledIndicator = indicator
                    stalledIndicator.itemstatus = .stalled
                    stalledIndicator.lastUpdate = now
                    self.transmissionStatus[key] = stalledIndicator
                    updatedAny = true
                }
            }

            if updatedAny {
                self.checkAllItemsSent()
            }
        }
    }

    private func closeShareExtension() {
        // Closing share extension
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
}

enum ShareMessageStatus: Int {
    case statusUnknown = 0
    case sending
    case sent
    case displayed
    case failure
    case canceled

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
    var transferId: String? = nil
    var itemstatus: TransmissionStatus = .pending
    var lastUpdate: Date = Date()

    static func makeKey(accountId: String, convid: String, itemIdentifier: String) -> String {
        return "\(accountId)|\(convid)|\(itemIdentifier)"
    }
}

enum TransmissionStatus: String {
    case pending = "Pending"
    case ongoing = "Sending"
    case sent = "Sent"
    case failed = "Sending Failed"
    case stalled = "Sending Stalling"
}
