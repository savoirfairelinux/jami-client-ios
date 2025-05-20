import RxSwift
import Combine

class ShareViewModel: ObservableObject {
    @Published var fileTransferStatus: String = ""
    @Published var accountList: [String] = []
    @Published var conversationsByAccount: [String: [String]] = [:]
    @Published var newStatusIndicators: [String: NewStatusIndicator] = [:]

    enum TransmissionStatus: String {
        case pending = "Pending"
        case ongoing = "Sending"
        case sent = "Sent"
        case failed = "Sending Failed"
        case stalled = "Sending Stalling"
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
        var itemstatus: TransmissionStatus = .pending
        var lastUpdate: Date = Date()

        static func makeKey(accountId: String, convid: String, itemIdentifier: String) -> String {
            return "\(accountId)|\(convid)|\(itemIdentifier)"
        }
    }

    private let disposeBag = DisposeBag()
    private var sendFileDisposeBag = DisposeBag()

    private var adapter: Adapter
    private var adapterService: AdapterService
    private var ongoingTransfersByAccount: [String: Set<String>] = [:]

    private var stallTimer: Timer?

    init(sharedItems: [NSExtensionItem]) {
        self.adapter = Adapter()
        self.adapter.initDaemon()
        self.adapter.startDaemon()
        self.adapterService = AdapterService(withAdapter: adapter)

        subscribeToFileTransferStatus()
        subscribeToNewInteractions()
        subscribeToMessageStatusChanged()
        fetchAccountsAndConversations()
        startStallMonitoring()
    }

    private func subscribeToFileTransferStatus() {
        adapterService.newInteractionStream
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] event in
                guard let self = self else { return }

                let interaction = event.interaction

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
                        var updatedIndicator = indicator
                        updatedIndicator.messageid = interaction.messageId
                        updatedIndicator.lastUpdate = Date()
                        self.newStatusIndicators[key] = updatedIndicator
                        break
                    }
                }
            })
            .disposed(by: disposeBag)
    }

    private func subscribeToNewInteractions() {
        adapterService.newInteractionStream
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] event in
                let _ = event.interaction
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

                    var updated = indicator

                    switch ShareMessageStatus(rawValue: Int(event.status.rawValue)) {
                        case .sending:
                            updated.itemstatus = .ongoing
                        case .sent, .displayed:
                            updated.itemstatus = .sent
                        case .failure, .canceled:
                            updated.itemstatus = .failed
                        default:
                            break
                    }

                    updated.lastUpdate = Date()
                    self.newStatusIndicators[key] = updated
                }

                self.checkAllItemsSent()
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
        newStatusIndicators[key] = NewStatusIndicator(
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

        sendFileDisposeBag = DisposeBag()

        adapterService.fileTransferStatusStream
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] status in
                guard let self = self,
                      let event = DataTransferEvent(rawValue: UInt32(status.eventCode)) else { return }

                let transferId = status.transferId
                var activeTransfers = self.ongoingTransfersByAccount[accountId] ?? Set<String>()

                var transmissionStatus: TransmissionStatus = .pending

                switch event {
                case .created, .waitPeerAcceptance, .waitHostAcceptance, .ongoing:
                    transmissionStatus = .ongoing
                case .finished:
                    transmissionStatus = .sent
                case .invalid, .unsupported, .closedByHost, .closedByPeer, .invalidPathname, .unjoinablePeer:
                    transmissionStatus = .failed
                default:
                    break
                }

                if let key = self.newStatusIndicators.first(where: {
                    $0.value.type == .file &&
                    $0.value.accountid == accountId &&
                    $0.value.convid == conversationId &&
                    $0.value.itemIdentifier == fileName
                })?.key {
                    var updated = self.newStatusIndicators[key]!
                    updated.itemstatus = transmissionStatus
                    updated.lastUpdate = Date()
                    self.newStatusIndicators[key] = updated
                }

                switch event {
                case .created:
                    activeTransfers.insert(transferId)
                    self.ongoingTransfersByAccount[accountId] = activeTransfers
                case .finished, .closedByHost, .closedByPeer, .invalidPathname, .unjoinablePeer:
                    activeTransfers.remove(transferId)
                    self.ongoingTransfersByAccount[accountId] = activeTransfers
                    self.adapterService.setUpdatedConversations(accountId: accountId, conversationId: conversationId)
                    if activeTransfers.isEmpty {
                        self.adapterService.setAccountActive(accountId, newValue: false)
                    }
                default:
                    self.adapterService.setUpdatedConversations(accountId: accountId, conversationId: conversationId)
                }

                self.checkAllItemsSent()
            })
            .disposed(by: sendFileDisposeBag)
    }

    private func checkAllItemsSent() {
        let indicators = newStatusIndicators.values

        let allFinal = indicators.allSatisfy {
            $0.itemstatus == .sent || $0.itemstatus == .failed || $0.itemstatus == .stalled
        }

        if allFinal {
            let sentCount = indicators.filter { $0.itemstatus == .sent }.count
            let failedCount = indicators.filter { $0.itemstatus == .failed }.count
            let stalledCount = indicators.filter { $0.itemstatus == .stalled }.count

            print("✅ All items finalized. Summary:")
            print("   🟢 Sent: \(sentCount)")
            print("   🔴 Failed: \(failedCount)")
            print("   🟡 Stalled: \(stalledCount)")

            closeShareExtension()
        }
    }

    private func startStallMonitoring() {
        stallTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let now = Date()
            var updatedAny = false

            for (key, indicator) in self.newStatusIndicators {
                if indicator.itemstatus == .ongoing, now.timeIntervalSince(indicator.lastUpdate) > 15 {
                    var stalledIndicator = indicator
                    stalledIndicator.itemstatus = .stalled
                    stalledIndicator.lastUpdate = now
                    self.newStatusIndicators[key] = stalledIndicator
                    print("⏱️ \(indicator.itemIdentifier) is stalling.")
                    updatedAny = true
                }
            }

            if updatedAny {
                self.checkAllItemsSent()
            }
        }
    }

    private func closeShareExtension() {
        // Implement the logic to close your share extension
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
