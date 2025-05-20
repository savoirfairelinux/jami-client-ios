import RxSwift

class ShareViewModel: ObservableObject {
    @Published var fileTransferStatus: String = ""
    @Published var accountList: [String] = []
    @Published var conversationsByAccount: [String: [String]] = [:]

    private var notificationObserver: Any?
    private let disposeBag = DisposeBag()

    private var adapter: Adapter
    private var adapterService: AdapterService

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
                NotificationCenter.default.post(
                    name: .fileTransferStatusUpdated,
                    object: status
                )
            })
            .disposed(by: disposeBag)

        notificationObserver = NotificationCenter.default.addObserver(
            forName: .fileTransferStatusUpdated,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let status = notification.object as? jamiShareExtension.AdapterService.FileTransferStatus,
               let event = DataTransferEvent(rawValue: UInt32(status.eventCode)) {
                self?.fileTransferStatus = "Transfer ID \(status.transferId): \(event.description)"
            } else {
                self?.fileTransferStatus = "Unknown transfer status"
            }
        }
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

    func sendMessage(accountId: String, conversationId: String, message: String, parentId: String?) {
        adapterService.sendSwarmMessage(accountId: accountId, conversationId: conversationId, message: message, parentId: parentId ?? "")
        adapterService.sendSwarmMessage(accountId: accountId, conversationId: conversationId, message: message, parentId: parentId ?? "")
    }

    func sendFile(accountId: String, conversationId: String, filePath: String, fileName: String, parentId: String?) {
        adapterService.setAccountActive(accountId, newValue: true)
        
        adapterService.sendSwarmFile(
            accountId: accountId,
            conversationId: conversationId,
            filePath: filePath,
            fileName: fileName,
            parentId: parentId ?? ""
        )

        adapterService.fileTransferStatusStream
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] status in
                if let event = DataTransferEvent(rawValue: UInt32(status.eventCode)) {
                    switch event {
                    case .finished, .closedByHost, .closedByPeer, .invalidPathname, .unjoinablePeer:
                        self?.adapterService.setAccountActive(accountId, newValue: false)
                        self?.adapterService.setUpdatedConversations(accountId: accountId, conversationId: conversationId)
                    default:
                        break
                    }
                }
            })
            .disposed(by: disposeBag)
    }

    deinit {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
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
