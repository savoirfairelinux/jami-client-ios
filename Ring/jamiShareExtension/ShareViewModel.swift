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
import UniformTypeIdentifiers
import MobileCoreServices
import CryptoKit
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
    @Published var transmissionStatus: [String: NewStatusIndicator] = [:] 

    
    
    init(sharedItems: [NSExtensionItem]) {
        self.adapter = Adapter()
        self.adapter.initDaemon() 
        self.adapter.startDaemon() 
        self.adapterService = AdapterService(withAdapter: adapter) 

        
        fetchAccountsAndConversations()

        
        subscribeToNewInteractions()
        subscribeToFileTransferStatus()
        subscribeToMessageStatusChanged()

        
        startStallMonitoring()
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

                
                if let key = self.transmissionStatus.first(where: {
                    $0.value.type == .file &&
                        $0.value.messageid == interactionId
                })?.key {

                    var updated = self.transmissionStatus[key]!

                    
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
                }
            })
            .disposed(by: disposeBag) 
    }

    
    
    private func fetchAccountsAndConversations() {
        let convsByAccount = adapterService.getConversationsByAccount()
        guard !convsByAccount.isEmpty else { return }

        
        
        for (accountId, conversationIds) in convsByAccount {
            
            let accountViewModel = AccountViewModel(id: accountId, adapterService: adapterService)
            self.accountList.append(accountViewModel)

            var conversationViewModels: [ConversationViewModel] = []
            for convoId in conversationIds {
                
                let conversationViewModel = ConversationViewModel(id: convoId, accountId: accountId, adapterService: adapterService)
                conversationViewModels.append(conversationViewModel)
            }
            
            self.conversationsByAccount[accountId] = conversationViewModels
            adapterService.setAccountActive(accountId, newValue: false)
        }
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
                self.adapterService.setUpdatedConversations(accountId: first.accountid, conversationId: first.convid)
            }
        }
    }

    
    private func startStallMonitoring() {
        stallTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let now = Date()
            var updatedAny = false

            
            for (key, indicator) in self.transmissionStatus {
                if indicator.itemstatus == .ongoing, now.timeIntervalSince(indicator.lastUpdate) > 5 {
                    
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
        for account in self.accountList {
            adapterService.setAccountActive(account.id, newValue: false)
        }

        adapterService.removeDelegate()
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
