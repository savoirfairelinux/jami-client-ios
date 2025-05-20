import RxSwift
import Combine

class ShareViewModel: ObservableObject {
    @Published var fileTransferStatus: String = ""
    @Published var accountList: [String] = []
    @Published var conversationsByAccount: [String: [String]] = [:]

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
        fetchAccountsAndConversations()
    }

    private func subscribeToFileTransferStatus() {
        adapterService.fileTransferStatusStream
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] status in
                guard let self = self,
                      let event = DataTransferEvent(rawValue: UInt32(status.eventCode)) else {
                    self?.fileTransferStatus = "Unknown transfer status"
                    return
                }
                self.fileTransferStatus = "Transfer ID \(status.transferId): \(event.description)"
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
        adapterService.sendSwarmMessage(
            accountId: accountId,
            conversationId: conversationId,
            message: message,
            parentId: parentId ?? ""
        )
    }

    func sendFile(accountId: String, conversationId: String, filePath: String, fileName: String, parentId: String? = nil) {
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
