/*
 * Copyright (C) 2023 Savoir-faire Linux Inc. *
 *
 * Author: Alireza Toghiani Khorasgani alireza.toghiani@savoirfairelinux.com
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version. *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details. *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

import RxCocoa
import RxSwift
import UIKit
import MobileCoreServices
import Photos
import os

class ShareAdapterService {

    private let maxSizeForAutoaccept = 20 * 1024 * 1024

    private var adapter: ShareAdapter!

    // Account Service
    private var accountList: [ShareAccountModel] = [] {
        didSet {
            self.currentAccount = self.accountList.first
        }
    }
    var currentAccount: ShareAccountModel?
    var accountsObservable = BehaviorRelay<[ShareAccountModel]>(value: [ShareAccountModel]())
    // Conversation Service
    var conversations = BehaviorRelay(value: [[ShareConversationModel]]())
    private var conversationList: [[ShareConversationModel]] = []
    // Profile Service
    var profiles = [String: ReplaySubject<Profile>]()

    private var disposeBag = DisposeBag()

    init(withAdapter adapter: ShareAdapter) {
        self.adapter = adapter
    }

    func start() {
        self.adapter.start()
    }

    func removeDelegate() {
        self.adapter = nil
    }

    func stop() {
        self.adapter.stop()
        removeDelegate()
    }

    // MARK: - Account Service

    private func loadAccountsFromDaemon() {
        let selectedAccount = self.currentAccount
        self.accountList.removeAll()
        for accountId in adapter.getAccountList() {
            print("****** Account ID => ", accountId)
            if  let id = accountId as? String {
                self.accountList.append(ShareAccountModel(withAccountId: id))
            }
        }
        self.reloadAccounts()
        accountsObservable.accept(self.accountList)
        if selectedAccount != nil {
            let currentAccount = self.accountList.filter({ account in
                return account == selectedAccount
            }).first
            if let currentAccount = currentAccount,
               let index = self.accountList.firstIndex(of: currentAccount) {
                self.accountList.remove(at: index)
                self.accountList.insert(currentAccount, at: 0)
            }
        }
    }

    private func reloadAccounts() {
        conversationList = []
        for account in accountList {
            //            account.details = self.getAccountDetails(fromAccountId: account.id)
            //            account.volatileDetails = self.getVolatileAccountDetails(fromAccountId: account.id)
            getConversationsForAccount(accountId: account.id, accountURI: account.jamiId)
        }
        conversations.accept(conversationList)
    }

    func loadAccounts() -> Single<[ShareAccountModel]> {
        return Single<[ShareAccountModel]>.just({
            loadAccountsFromDaemon()
            return accountList
        }())
    }
}

// MARK: Account Service
extension ShareAdapterService {
    func isJams(for accountId: String) -> Bool {
        guard let account = self.getAccount(fromAccountId: accountId) else { return false }
        return account.isJams
    }

    /**
     Gets an account from the list of accounts handled by the application.

     - Parameter id: the id of the account to get.

     - Returns: the account if found, nil otherwise.
     */
    func getAccount(fromAccountId id: String) -> ShareAccountModel? {
        for account in self.accountList
        where id.compare(account.id) == ComparisonResult.orderedSame {
            return account
        }
        return nil
    }
}

// MARK: - Converstion Service
extension ShareAdapterService {
    private func addSwarm(conversationId: String, accountId: String, accountURI: String, to conversations: inout [ShareConversationModel]) {
        if let info = adapter.getConversationInfo(forAccount: accountId, conversationId: conversationId) as? [String: String],
           let participantsInfo = adapter.getConversationMembers(accountId, conversationId: conversationId) {
            let conversation = ShareConversationModel(withId: conversationId, accountId: accountId, info: info)
            conversation.addParticipantsFromArray(participantsInfo: participantsInfo, accountURI: accountURI)
            conversations.append(conversation)
        }
    }

    /**
     Called when application starts and when  account changed
     */
    func getConversationsForAccount(accountId: String, accountURI: String) {
        /* if we don't have conversation that could mean the app
         just launched and we need symchronize messages status
         */
        var currentConversations = [ShareConversationModel]()
        // get swarms conversations
        if let swarmIds = adapter.getSwarmConversations(forAccount: accountId) as? [String] {
            for swarmId in swarmIds {
                print("****** Conversation ID for Account ID \(accountId) => ", swarmId)
                self.addSwarm(conversationId: swarmId, accountId: accountId, accountURI: accountURI, to: &currentConversations)
            }
        }
        conversationList.append(currentConversations)
    }

    func getSwarmMembers(conversationId: String, accountId: String, accountURI: String) -> [ShareParticipantInfo] {
        if let participantsInfo = adapter.getConversationMembers(accountId, conversationId: conversationId) {
            return participantsInfo.compactMap({ info in
                if let jamiId = info["uri"],
                   let roleText = info["role"] {
                    var role = ParticipantRole.member
                    switch roleText {
                    case "admin":
                        role = .admin
                    case "member":
                        role = .member
                    case "invited":
                        role = .invited
                    case "banned":
                        role = .banned
                    default:
                        role = .unknown
                    }
                    return ShareParticipantInfo(jamiId: jamiId, role: role)
                }
                return nil
            })
        }
        return []
    }

    func getConversationInfo(conversationId: String, accountId: String) -> [String: String] {
        return adapter.getConversationInfo(forAccount: accountId, conversationId: conversationId) as? [String: String] ?? [String: String]()
    }
}

// MARK: - Profile Service
extension ShareAdapterService {
    func getProfile(uri: String, createIfNotexists: Bool, accountId: String) -> Observable<Profile> {
        if let profile = self.profiles[uri] {
            return profile.asObservable().share()
        }
        let profileObservable = ReplaySubject<Profile>.create(bufferSize: 1)
        self.profiles[uri] = profileObservable
        return profileObservable.share()
    }
}
