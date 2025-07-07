/*
 *  Copyright (C) 2025-2025 Savoir-faire Linux Inc.
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

import SwiftUI
import RxSwift

class ShareViewModel: ObservableObject {
    private let disposeBag = DisposeBag()
    private var adapter: Adapter
    private var adapterService: AdapterService
    private var ongoingTransfersByAccount: [String: Set<String>] = [:]
    private var stallTimer: Timer?
    private var didSetTransmissionSummary = false

    @Published var accountList: [AccountViewModel] = []
    @Published var conversationsByAccount: [String: [ConversationViewModel]] = [:]
    @Published var transmissionSummary: String = ""
    @Published var shouldCloseExtension: Bool = false
    @Published var isLoading: Bool = true
    var transmissionStatus: [String: NewStatusIndicator] = [:]

    init() {
        self.adapter = Adapter()
        self.adapterService = AdapterService(withAdapter: adapter)

        // Check if daemon can be started (waits up to 10 seconds for notification extension)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let canStart = self.adapterService.canStartDaemon()
            if canStart {
                self.adapterService.startDaemon()

                self.subscribeToNewInteractions()
                self.subscribeToFileTransferStatus()
                self.subscribeToMessageStatusChanged()

                self.startStallMonitoring()
            }

            DispatchQueue.main.async {[weak self] in
                guard let self = self else { return }
                self.isLoading = false
                self.shouldCloseExtension = !canStart
                if canStart {
                    self.fetchAccountsAndConversations()
                }
            }
        }
    }

    private func subscribeToNewInteractions() {
        adapterService.newInteractionStream
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] event in
                guard let self = self else { return }

                let interaction = event

                for (key, indicator) in self.transmissionStatus {
                    var messageIdToAssign: String?
                    var transferIdToAssign: String?

                    switch indicator.type {
                    case .text:

                        if let bodyText = interaction.body["body"] as? String,
                           bodyText.trimmingCharacters(in: .whitespacesAndNewlines) == indicator.itemIdentifier {
                            messageIdToAssign = interaction.messageId
                        }
                    case .file:

                        if let displayName = interaction.body["displayName"] as? String,
                           displayName == indicator.itemIdentifier,
                           let messageId = interaction.body["id"] as? String,
                           let fileId = interaction.body["fileId"] as? String {
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

                if let (key, value) = self.transmissionStatus.first(where: {
                    $0.value.type == .file && $0.value.messageid == interactionId
                }) {
                    var updated = value

                    switch event {
                    case .created, .waitPeerAcceptance, .waitHostAcceptance, .ongoing:
                        updated.itemstatus = .ongoing
                    case .finished:
                        updated.itemstatus = .sent
                    case .invalid, .unsupported, .closedByHost, .closedByPeer, .invalidPathname, .unjoinablePeer:
                        updated.itemstatus = .failed
                    }

                    updated.lastUpdate = Date()
                    self.transmissionStatus[key] = updated

                    let accountId = updated.accountid
                    var activeTransfers = self.ongoingTransfersByAccount[accountId] ?? Set<String>()

                    switch event {
                    case .created:
                        activeTransfers.insert(transferId)
                        self.ongoingTransfersByAccount[accountId] = activeTransfers
                    case .finished, .closedByHost, .closedByPeer, .invalidPathname, .unjoinablePeer:
                        activeTransfers.remove(transferId)
                        self.ongoingTransfersByAccount[accountId] = activeTransfers
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

                if let (key, value) = self.transmissionStatus.first(where: {
                    response in
                    response.value.type == .text &&
                        response.value.accountid == accountId &&
                        response.value.convid == conversationId &&
                        response.value.messageid == interactionId
                }) {
                    var updated = value

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
                }
            })
            .disposed(by: disposeBag)
    }

    private func fetchAccountsAndConversations() {
        let convsByAccount = adapterService.getConversationsByAccount()
        guard !convsByAccount.isEmpty else { return }

        let defaultAccountId = getDefaultAccount()

        let sortedAccounts = convsByAccount.sorted { first, _ in
            first.key == defaultAccountId
        }

        for (accountId, conversationIds) in sortedAccounts {

            let accountViewModel = AccountViewModel(id: accountId, adapterService: adapterService)
            self.accountList.append(accountViewModel)

            var conversationViewModels: [ConversationViewModel] = []
            for convoId in conversationIds {
                let conversationViewModel = ConversationViewModel(id: convoId, accountId: accountId, adapterService: adapterService)
                conversationViewModels.append(conversationViewModel)
            }

            self.conversationsByAccount[accountId] = conversationViewModels
        }

        adapterService.setAllAccountsInactive()
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

    func sendFile(accountId: String, conversationId: String, filePath: URL, fileName: String, parentId: String? = nil) {
        let key = NewStatusIndicator.makeKey(accountId: accountId, convid: conversationId, itemIdentifier: fileName)

        transmissionStatus[key] = NewStatusIndicator(
            type: .file,
            itemIdentifier: fileName,
            convid: conversationId,
            accountid: accountId,
            itemstatus: .ongoing,
            lastUpdate: Date()
        )

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

        if allFinal && !didSetTransmissionSummary {
            didSetTransmissionSummary = true

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
                CommonHelpers.setUpdatedConversations(accountId: first.accountid, conversationId: first.convid)
            }
        }
    }

    private func startStallMonitoring() {
        stallTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let now = Date()
            var updatedAny = false

            for (key, indicator) in self.transmissionStatus {
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

    func closeShareExtension() {
        adapterService.setAllAccountsInactive()

        if let timer = stallTimer {
            timer.invalidate()
            stallTimer = nil
        }

        adapterService.removeDelegate()
    }

    func getDefaultAccount() -> String? {
        guard let sharedDefaults = UserDefaults(suiteName: Constants.appGroupIdentifier),
              let selectedAccountID = sharedDefaults.string(forKey: Constants.selectedAccountID) else {
            return nil
        }
        return selectedAccountID
    }

    deinit {
        adapterService.removeDelegate()
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
    var messageid: String?
    var transferId: String?
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
