import SwiftUI
import UniformTypeIdentifiers
import MobileCoreServices
import CryptoKit
import RxSwift

// MARK: - ShareViewModel

/// Main ViewModel for the share extension, managing overall state and interactions.
class ShareViewModel: ObservableObject {
    private let disposeBag = DisposeBag() // Dispose bag for RxC to manage subscriptions
    private var adapter: Adapter // Core adapter for communication
    private var adapterService: AdapterService // Service built on top of the adapter
    private var ongoingTransfersByAccount: [String: Set<String>] = [:] // Tracks active file transfers
    private var stallTimer: Timer? // Timer for monitoring stalled transfers
    private var didSetTransmissionSummary = false // Flag to prevent multiple summary generations

    // Published properties for UI updates
    @Published var accountList: [AccountViewModel] = [] // List of account ViewModels
    @Published var conversationsByAccount: [String: [ConversationViewModel]] = [:] // Dictionary of conversation ViewModels by account ID
    @Published var transmissionSummary: String = "" // Summary of transmission status
    @Published var transmissionStatus: [String: NewStatusIndicator] = [:] // Detailed status of each transmission

    /// Initializes the ShareViewModel.
    /// - Parameter sharedItems: The items shared with the extension.
    init(sharedItems: [NSExtensionItem]) {
        self.adapter = Adapter()
        self.adapter.initDaemon() // Initialize the adapter daemon
        self.adapter.startDaemon() // Start the adapter daemon
        self.adapterService = AdapterService(withAdapter: adapter) // Initialize the adapter service

        // Load accounts and conversations using the new ViewModel pattern
        fetchAccountsAndConversations()
        
        // Subscribe to various status streams to track transmissions
        subscribeToNewInteractions()
        subscribeToFileTransferStatus()
        subscribeToMessageStatusChanged()

        // Start monitoring for stalled transfers
        startStallMonitoring()
    }

    /// Subscribes to new interaction events to assign unique IDs to pending transmissions.
    private func subscribeToNewInteractions() {
        adapterService.newInteractionStream
            .observe(on: MainScheduler.instance) // Ensure updates are on the main thread
            .subscribe(onNext: { [weak self] event in
                guard let self = self else { return }

                let interaction = event.interaction

                // Iterate through existing transmission statuses to find a match and assign IDs
                for (key, indicator) in self.transmissionStatus {
                    var messageIdToAssign: String? = nil
                    var transferIdToAssign: String? = nil

                    switch indicator.type {
                    case .text:
                        // For text, match by body content
                        if let bodyText = interaction.body["body"] as? String,
                           bodyText.trimmingCharacters(in: .whitespacesAndNewlines) == indicator.itemIdentifier {
                            messageIdToAssign = interaction.messageId
                        }
                    case .file:
                        // For files, match by display name and extract message/file IDs
                        if let displayName = interaction.body["displayName"] as? String,
                           displayName == indicator.itemIdentifier,
                           let messageId = interaction.body["id"] as? String,
                           let fileId = interaction.body["fileId"] as? String {
                            messageIdToAssign = messageId
                            transferIdToAssign = fileId
                        }
                    }

                    // If a match is found, update the indicator with the assigned IDs
                    if let messageId = messageIdToAssign {
                        var updatedIndicator = indicator
                        updatedIndicator.messageid = messageId
                        updatedIndicator.transferId = transferIdToAssign ?? updatedIndicator.transferId
                        updatedIndicator.lastUpdate = Date()
                        self.transmissionStatus[key] = updatedIndicator
                        break // Stop after finding the first match
                    }
                }
            })
            .disposed(by: disposeBag) // Add subscription to dispose bag
    }

    /// Subscribes to file transfer status updates.
    private func subscribeToFileTransferStatus() {
        adapterService.fileTransferStatusStream
            .observe(on: MainScheduler.instance) // Ensure updates are on the main thread
            .subscribe(onNext: { [weak self] status in
                guard let self = self,
                      let event = DataTransferEvent(rawValue: UInt32(status.eventCode)) else { return }

                let transferId = status.transferId
                let interactionId = status.interactionId

                // Find the corresponding NewStatusIndicator key using the interactionId (messageId for files)
                if let key = self.transmissionStatus.first(where: {
                    $0.value.type == .file &&
                    $0.value.messageid == interactionId
                })?.key {
                    
                    var updated = self.transmissionStatus[key]!
                    
                    // Map the DataTransferEvent to an internal TransmissionStatus
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
                    self.transmissionStatus[key] = updated // Update the published status dictionary

                    // Manage ongoing file transfers for account activity tracking
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
                            // If no more active transfers for this account, set it inactive
                            self.adapterService.setAccountActive(accountId, newValue: false)
                        }
                    default:
                        break
                    }

                    self.checkAllItemsSent() // Check if all items are finalized
                }
            })
            .disposed(by: disposeBag) // Add subscription to dispose bag
    }

    /// Subscribes to message status changes.
    private func subscribeToMessageStatusChanged() {
        adapterService.messageStatusChangedStream
            .observe(on: MainScheduler.instance) // Ensure updates are on the main thread
            .subscribe(onNext: { [weak self] event in
                guard let self = self else { return }

                let interactionId = event.messageId
                let accountId = event.accountId
                let conversationId = event.conversationId
                let rawStatus = Int(event.status.rawValue)
                
                guard let msgStatus = ShareMessageStatus(rawValue: rawStatus) else { return }

                // Find the corresponding NewStatusIndicator for text messages
                if let key = self.transmissionStatus.first(where: {
                    $0.value.type == .text &&
                    $0.value.accountid == accountId &&
                    $0.value.convid == conversationId &&
                    $0.value.messageid == interactionId
                })?.key {

                    var updated = self.transmissionStatus[key]!

                    // Map the ShareMessageStatus to an internal TransmissionStatus
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
                    self.transmissionStatus[key] = updated // Update the published status dictionary
                    self.checkAllItemsSent() // Check if all items are finalized
                }
            })
            .disposed(by: disposeBag) // Add subscription to dispose bag
    }

    /// Fetches accounts and conversations and populates the published lists with placeholder ViewModels.
    /// The actual data fetching is delegated to `AccountViewModel` and `ConversationViewModel`.
    private func fetchAccountsAndConversations() {
        let convsByAccount = adapterService.getConversationsByAccount()
        guard !convsByAccount.isEmpty else { return }

        // Populate `accountList` and `conversationsByAccount` with ViewModels immediately.
        // Each ViewModel will then asynchronously fetch its own details.
        for (accountId, conversationIds) in convsByAccount {
            // Create an AccountViewModel with placeholder data right away
            let accountViewModel = AccountViewModel(id: accountId, adapterService: adapterService)
            self.accountList.append(accountViewModel)

            var conversationViewModels: [ConversationViewModel] = []
            for convoId in conversationIds {
                // Create a ConversationViewModel with placeholder data right away
                let conversationViewModel = ConversationViewModel(id: convoId, accountId: accountId, adapterService: adapterService)
                conversationViewModels.append(conversationViewModel)
            }
            // Assign the array of ConversationViewMoels to the dictionary
            self.conversationsByAccount[accountId] = conversationViewModels
        }
    }

    /// Sends a text message through the adapter service.
    /// - Parameters:
    ///   - accountId: The ID of the account to send from.
    ///   - conversationId: The ID of the conversation to send to.
    ///   - message: The text message content.
    ///   - parentId: Optional parent message ID for replies.
    func sendMessage(accountId: String, conversationId: String, message: String, parentId: String? = nil) {
        let key = NewStatusIndicator.makeKey(accountId: accountId, convid: conversationId, itemIdentifier: message)
        // Initialize transmission status as ongoing
        transmissionStatus[key] = NewStatusIndicator(
            type: .text,
            itemIdentifier: message,
            convid: conversationId,
            accountid: accountId,
            itemstatus: .ongoing,
            lastUpdate: Date()
        )

        adapterService.setAccountActive(accountId, newValue: true) // Set account active

        adapterService.sendSwarmMessage(
            accountId: accountId,
            conversationId: conversationId,
            message: message,
            parentId: parentId ?? ""
        )
    }

    /// Sends a file through the adapter service.
    /// - Parameters:
    ///   - accountId: The ID of the account to send from.
    ///   - conversationId: The ID of the conversation to send to.
    ///   - filePath: The local path to the file.
    ///   - fileName: The name of the file.
    ///   - parentId: Optional parent message ID.
    func sendFile(accountId: String, conversationId: String, filePath: String, fileName: String, parentId: String? = nil) {
        let key = NewStatusIndicator.makeKey(accountId: accountId, convid: conversationId, itemIdentifier: fileName)
        // Initialize transmission status as ongoing
        transmissionStatus[key] = NewStatusIndicator(
            type: .file,
            itemIdentifier: fileName,
            convid: conversationId,
            accountid: accountId,
            itemstatus: .ongoing,
            lastUpdate: Date()
        )

        adapterService.setAccountActive(accountId, newValue: true) // Set account active

        adapterService.sendSwarmFile(
            accountId: accountId,
            conversationId: conversationId,
            filePath: filePath,
            fileName: fileName,
            parentId: parentId ?? ""
        )
    }

    /// Checks if all initiated transmissions have reached a final state (sent, failed, or stalled).
    private func checkAllItemsSent() {
        let indicators = transmissionStatus.values

        // Determine if all items are in a final status
        let allFinal = indicators.allSatisfy {
            $0.itemstatus == .sent || $0.itemstatus == .failed || $0.itemstatus == .stalled
        }

        if allFinal && !didSetTransmissionSummary {
            didSetTransmissionSummary = true // Set flag to prevent re-execution

            // Calculate counts for summary
            let sentCount = indicators.filter { $0.itemstatus == .sent }.count
            let failedCount = indicators.filter { $0.itemstatus == .failed }.count
            let stalledCount = indicators.filter { $0.itemstatus == .stalled }.count

            // Update the published transmission summary
            transmissionSummary = """
            ✅ All items finalized. Summary:
                🟢 Sent: \(sentCount)
                🟡 Stalled: \(stalledCount)
                🔴 Failed: \(failedCount)
            """

            // Inform the adapter service about updated conversations if any items were sent
            if let first = indicators.first {
                self.adapterService.setUpdatedConversations(accountId: first.accountid, conversationId: first.convid)
            }

            adapterService.removeDelegate()
            closeShareExtension() // Close the share extension
        }
    }

    /// Starts a timer to monitor for stalled ongoing transmissions.
    private func startStallMonitoring() {
        stallTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let now = Date()
            var updatedAny = false

            // Iterate through ongoing transmissions to detect stalls
            for (key, indicator) in self.transmissionStatus {
                if indicator.itemstatus == .ongoing, now.timeIntervalSince(indicator.lastUpdate) > 15 {
                    // Mark as stalled if no update for 15 seconds
                    var stalledIndicator = indicator
                    stalledIndicator.itemstatus = .stalled
                    stalledIndicator.lastUpdate = now
                    self.transmissionStatus[key] = stalledIndicator
                    updatedAny = true
                }
            }

            if updatedAny {
                self.checkAllItemsSent() // Re-check overall status if any item stalled
            }
        }
    }

    /// Placeholder function to close the share extension.
    private func closeShareExtension() {
        // Implementation for closing the share extension would go here.
        // This typically involves calling `extensionContext?.completeRequest(...)` in a real iOS share extension.
    }
}

// MARK: - Supporting Enums and Structs (from your original code, ensure these are defined)

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
    var itemIdentifier: String // Original content (text) or file name
    var convid: String // Conversation ID
    var accountid: String // Account ID
    var messageid: String? = nil // Assigned message ID from adapter
    var transferId: String? = nil // Assigned transfer ID for files from adapter
    var itemstatus: TransmissionStatus = .pending // Current transmission status
    var lastUpdate: Date = Date() // Last update timestamp for stall detection

    /// Creates a unique key for tracking transmission status.
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
