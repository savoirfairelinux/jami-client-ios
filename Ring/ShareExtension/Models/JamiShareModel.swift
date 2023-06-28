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

import Foundation
import RxSwift

class ShareJamiURI {
    var schema: URIType
    var userInfo: String = ""
    var hostname: String = ""
    var port: String = ""

    init(schema: URIType) {
        self.schema = schema
    }

    init(schema: URIType, infoHash: String, account: ShareAccountModel) {
        self.schema = schema
        self.parce(infoHash: infoHash, account: account)
    }

    init(schema: URIType, infoHash: String) {
        self.schema = schema
        self.parce(infoHash: infoHash)
    }

    init(from uriString: String) {
        let prefix = uriString
            .replacingOccurrences(of: "<", with: "")
            .replacingOccurrences(of: ">", with: "")
            .prefix(3)
        if prefix == URIType.sip.getString() {
            self.schema = .sip
        } else {
            self.schema = .ring
        }
        self.parce(infoHash: uriString)
    }

    private func parce(infoHash: String, account: ShareAccountModel) {
        self.parce(infoHash: infoHash)
        if self.schema == .ring || self.userInfo.isEmpty {
            return
        }
        if self.hostname.isEmpty {
            self.hostname = account.details?
                .get(withConfigKeyModel: ConfigKeyModel(withKey: ConfigKey.accountHostname)) ?? ""
        }
        if self.port.isEmpty {
            self.port = account.details?
                .get(withConfigKeyModel: ConfigKeyModel(withKey: ConfigKey.localPort)) ?? ""
        }
    }

    private func parce(infoHash: String) {
        var info = infoHash.replacingOccurrences(of: "ring:", with: "")
            .replacingOccurrences(of: "sip:", with: "")
            .replacingOccurrences(of: "@ring.dht", with: "")
            .replacingOccurrences(of: "<", with: "")
            .replacingOccurrences(of: ">", with: "")
        if self.schema == .ring {
            userInfo = info
            return
        }
        if info.isEmpty { return }
        if info.firstIndex(of: "@") != nil {
            userInfo = String(info.split(separator: "@").first!)
            info = info.replacingOccurrences(of: userInfo + "@", with: "")
        } else {
            userInfo = info
            return
        }
        if info.firstIndex(of: ":") != nil {
            let parts = info.split(separator: ":")
            hostname = String(parts.first!)
            if parts.count == 2 {
                port = String(info.split(separator: ":")[1])
            }
        } else {
            hostname = info
        }
    }

    lazy var uriString: String? = {
        var infoString = self.schema.getString() + ":"
        if self.userInfo.isEmpty {
            return nil
        }
        if self.schema == .ring {
            infoString += self.userInfo
            return infoString
        }
        if self.hostname.isEmpty || self.port.isEmpty {
            return nil
        }
        infoString += self.userInfo + "@" + self.hostname + ":" + self.port
        return infoString
    }()

    lazy var hash: String? = {
        if self.userInfo.isEmpty {
            return nil
        }
        return self.userInfo
    }()

    lazy var isValid: Bool = {
        if self.schema == .ring {
            return !self.userInfo.isEmpty
        }
        return !self.userInfo.isEmpty &&
            !self.hostname.isEmpty &&
            !self.port.isEmpty
    }()
}

class ShareContactModel: Equatable {

    var hash: String = ""
    var userName: String?
    var uriString: String?
    var confirmed: Bool = false
    var added: Date = Date()
    var banned: Bool = false
    var type = URIType.ring

    static func == (lhs: ShareContactModel, rhs: ShareContactModel) -> Bool {
        return lhs.uriString == rhs.uriString
    }

    init(withUri contactUri: ShareJamiURI) {
        self.uriString = contactUri.uriString
        type = contactUri.schema
        self.hash = contactUri.hash ?? ""
    }

    // only jami contacts
    init(withDictionary dictionary: [String: String]) {
        if let hash = dictionary["id"] {
            self.hash = hash
            if let uriString = ShareJamiURI.init(schema: URIType.ring,
                                                 infoHash: hash).uriString {
                self.uriString = uriString
            }
        }

        if let confirmed = dictionary["confirmed"] {
            self.confirmed = confirmed.toBool() ?? false
        }

        if let added = dictionary["added"], let dateAdded = Double(added) {
            let addedDate = Date(timeIntervalSince1970: dateAdded)
            self.added = addedDate
        }
        if let banned = dictionary["banned"],
           let isBanned = banned.toBool() {
            self.banned = isBanned
        }
    }
}

class ShareAccountModel: Equatable {
    // MARK: Public members
    var id: String = ""
    var protectedDetails: AccountConfigModel? {
        willSet {
            if let newDetails = newValue {
                if !newDetails
                    .get(withConfigKeyModel: ConfigKeyModel(withKey: .accountUsername))
                    .isEmpty {
                    self.username = newDetails
                        .get(withConfigKeyModel: ConfigKeyModel(withKey: .accountUsername))
                }
                let accountType = newDetails
                    .get(withConfigKeyModel: ConfigKeyModel.init(withKey: .accountType))
                if let type = AccountType(rawValue: accountType) {
                    self.type = type
                }
                self.enabled = newDetails
                    .get(withConfigKeyModel: ConfigKeyModel.init(withKey: .accountEnable))
                    .boolValue
                let managerConfModel = ConfigKeyModel(withKey: .managerUri)
                let isJams = !newDetails.get(withConfigKeyModel: managerConfModel).isEmpty
                self.isJams = isJams
            }
        }
    }

    let detailsQueue = DispatchQueue(label: "com.accountDetailsAccess", qos: .background, attributes: .concurrent)

    var details: AccountConfigModel? {
        get {
            return detailsQueue.sync { protectedDetails }
        }

        set(newValue) {
            detailsQueue.sync(flags: .barrier) {[weak self] in
                self?.protectedDetails = newValue
            }
        }
    }

    //    var volatileDetails: AccountConfigModel? {
    //        get {
    //            return volatileDetailsQueue.sync { protectedVolatileDetails }
    //        }
    //
    //        set(newValue) {
    //            volatileDetailsQueue.sync(flags: .barrier) { [weak self] in
    //                self?.protectedVolatileDetails = newValue
    //            }
    //        }
    //    }

    let volatileDetailsQueue = DispatchQueue(label: "com.accountVolatileDetailsAccess", qos: .background, attributes: .concurrent)

    var protectedVolatileDetails: AccountConfigModel? {
        willSet {
            if let newDetails = newValue {
                if !newDetails
                    .get(withConfigKeyModel: ConfigKeyModel(withKey: .accountRegisteredName))
                    .isEmpty {
                    self.registeredName = newDetails.get(withConfigKeyModel: ConfigKeyModel(withKey: .accountRegisteredName))
                }
                if let status = AccountState(rawValue:
                                                newDetails.get(withConfigKeyModel:
                                                                ConfigKeyModel(withKey: .accountRegistrationStatus))) {
                    self.status = status
                }
            }
        }
    }
    var credentialDetails = [AccountCredentialsModel]()
    var devices = [DeviceModel]()
    var registeredName = ""
    var username = ""
    var jamiId: String {
        return self.username.replacingOccurrences(of: "ring:", with: "")
    }
    var type = AccountType.ring
    var isJams = false
    var status = AccountState.unregistered
    var enabled = true

    // MARK: Init
    convenience init(withAccountId accountId: String) {
        self.init()
        self.id = accountId
    }

    //    convenience init(withAccountId accountId: String,
    //                     details: AccountConfigModel,
    //                     volatileDetails: AccountConfigModel,
    //                     credentials: [AccountCredentialsModel],
    //                     devices: [DeviceModel]) throws {
    //        self.init()
    //        self.id = accountId
    //        self.details = details
    //        self.volatileDetails = volatileDetails
    //        self.devices = devices
    //    }

    static func == (lhs: ShareAccountModel, rhs: ShareAccountModel) -> Bool {
        return lhs.id == rhs.id
    }

}

class ShareConversationParticipant: Equatable, Hashable {
    var jamiId: String = ""
    var role: ParticipantRole = .member
    var lastDisplayed: String = ""
    var isLocal: Bool = false

    init (info: [String: String], isLocal: Bool) {
        self.isLocal = isLocal
        if let jamiId = info["uri"], !jamiId.isEmpty {
            self.jamiId = jamiId.replacingOccurrences(of: "ring:", with: "")
        }
        if let role = info["role"],
           let memberRole = ParticipantRole(rawValue: role) {
            self.role = memberRole
        }
        if let lastRead = info["lastDisplayed"] {
            self.lastDisplayed = lastRead
        }
    }

    init (jamiId: String) {
        self.jamiId = jamiId.replacingOccurrences(of: "ring:", with: "")
    }

    static func == (lhs: ShareConversationParticipant, rhs: ShareConversationParticipant) -> Bool {
        return lhs.jamiId == rhs.jamiId
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(jamiId)
    }
}

class ShareConversationModel: Equatable {
    private var participants = [ShareConversationParticipant]()
    var hash = ""/// contact hash for dialog, conversation title for multiparticipants
    var accountId: String = ""
    var id: String = ""
    var type: ConversationType = .nonSwarm
    var unorderedInteractions = [String]()/// array ofr interaction id with child not currently present in messages
    let disposeBag = DisposeBag()
    var avatar: String = ""
    var title: String = ""
    //    var synchronizing = BehaviorRelay<Bool>(value: false)

    convenience init(withParticipantUri participantUri: ShareJamiURI, accountId: String) {
        self.init()
        self.participants = [ShareConversationParticipant(jamiId: participantUri.hash ?? "")]
        self.hash = participantUri.hash ?? ""
        self.accountId = accountId
    }

    convenience init (withParticipantUri participantUri: ShareJamiURI, accountId: String, hash: String) {
        self.init()
        self.participants = [ShareConversationParticipant(jamiId: participantUri.hash ?? "")]
        self.hash = hash
        self.accountId = accountId
    }

    convenience init (withId conversationId: String, accountId: String) {
        self.init()
        self.id = conversationId
        self.accountId = accountId
    }

    convenience init (withId conversationId: String, accountId: String, info: [String: String]) {
        self.init()
        self.id = conversationId
        self.accountId = accountId
        self.updateInfo(info: info)
        updateProfile(profile: info)
    }

    func updateInfo(info: [String: String]) {
        //        if let syncing = info["syncing"], syncing == "true" {
        //            self.synchronizing.accept(true)
        //        } else {
        //            self.synchronizing.accept(false)
        //        }
        //        if let hash = info[ConversationAttributes.title.rawValue], !hash.isEmpty {
        //            self.hash = hash
        //        }
        //        if let type = info[ConversationAttributes.mode.rawValue],
        //           let typeInt = Int(type),
        //           let conversationType = ConversationType(rawValue: typeInt) {
        //            self.type = conversationType
        //        }
    }

    func updateProfile(profile: [String: String]) {
        if let avatar = profile[ConversationAttributes.avatar.rawValue] {
            self.avatar = avatar
        }
        if let title = profile[ConversationAttributes.title.rawValue] {
            self.title = title
        }
    }

    static func == (lhs: ShareConversationModel, rhs: ShareConversationModel) -> Bool {
        if lhs.type != rhs.type { return false }
        /*
         Swarm conversations must have an unique id, unless it temporary oneToOne
         conversation. For non swarm conversations and for temporary swarm
         conversations check participant and accountId.
         */
        if !lhs.isSwarm() && !rhs.isSwarm() || lhs.id.isEmpty || rhs.id.isEmpty {
            if let rParticipant = rhs.getParticipants().first, let lParticipant = lhs.getParticipants().first {
                return (lParticipant == rParticipant && lhs.accountId == rhs.accountId)
            }
            return false
        }
        return lhs.id == rhs.id
    }

    func addParticipantsFromArray(participantsInfo: [[String: String]], accountURI: String) {
        self.participants = [ShareConversationParticipant]()
        participantsInfo.forEach { participantInfo in
            guard let uri = participantInfo["uri"], !uri.isEmpty else { return }
            let isLocal = uri.replacingOccurrences(of: "ring:", with: "") == accountURI.replacingOccurrences(of: "ring:", with: "")
            let participant = ShareConversationParticipant(info: participantInfo, isLocal: isLocal)
            self.participants.append(participant)
        }
    }

    func isCoredialog() -> Bool {
        if self.participants.count > 2 { return false }
        return self.type == .nonSwarm || self.type == .oneToOne || self.type == .sip || self.type == .jams
    }

    func getParticipants() -> [ShareConversationParticipant] {
        return self.participants.filter { participant in
            !participant.isLocal
        }
    }

    func getAllParticipants() -> [ShareConversationParticipant] {
        return self.participants
    }

    func getLocalParticipants() -> ShareConversationParticipant? {
        return self.participants.filter { participant in
            participant.isLocal
        }.first
    }

    func isDialog() -> Bool {
        return self.participants.filter { participant in
            !participant.isLocal
        }.count == 1
    }

    func containsParticipant(participant: String) -> Bool {
        return self.getParticipants()
            .map { participant in
                return participant.jamiId
            }
            .contains(participant)
    }

    func getConversationURI() -> String? {
        if self.type == .nonSwarm {
            guard let jamiId = self.getParticipants().first?.jamiId else { return nil }
            return "jami:" + jamiId
        }
        return "swarm:" + self.id
    }

    func isSwarm() -> Bool {
        return self.type != .nonSwarm && self.type != .sip && self.type != .jams
    }
}

struct ShareConversationSection {
    var header: String
    var items: [Item]
}

extension ShareConversationSection {
    typealias Item = ShareConversationViewModel

    init(original: ShareConversationSection, items: [Item]) {
        self = original
        self.items = items
    }
}

struct ShareMessageModel {
    var url: URL?
    var content = ""
    var messageType: MessageType
    var type: MessageAttributes
}
