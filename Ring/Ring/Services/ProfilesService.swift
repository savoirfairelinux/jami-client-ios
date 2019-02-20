/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
 *
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
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

// swiftlint:disable identifier_name

import RxSwift
import SwiftyBeaver

enum ProfileNotifications: String {
    case messageReceived
    case contactAdded
}

enum ProfileNotificationsKeys: String {
    case ringID
    case accountId
    case message
}

struct Base64VCard {
    var data: [Int: String] //The key is the number of vCard part
    var partsReceived: Int
}

class ProfilesService {

    fileprivate let ringVCardMIMEType = "x-ring/ring.profile.vcard;"
    fileprivate var base64VCards = [Int: Base64VCard]()
    fileprivate let log = SwiftyBeaver.self

    var profiles = [String: ReplaySubject<Profile>]()

    let dbManager = DBManager(profileHepler: ProfileDataHelper(),
                              conversationHelper: ConversationDataHelper(),
                              interactionHepler: InteractionDataHelper(),
                              accountProfileHelper: AccountProfileHelper())

    let disposeBag = DisposeBag()

    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.messageReceived(_:)),
                                               name: NSNotification.Name(rawValue: ProfileNotifications.messageReceived.rawValue),
                                               object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.contactAdded(_:)),
                                               name: NSNotification.Name(rawValue: ProfileNotifications.contactAdded.rawValue),
                                               object: nil)
    }

    @objc private func contactAdded(_ notification: NSNotification) {
        guard let ringId = notification.userInfo?[ProfileNotificationsKeys.ringID.rawValue] as? String else {
            return
        }
        self.updateProfileFor(ringId: ringId)
    }

    // swiftlint:disable cyclomatic_complexity
    @objc private func messageReceived(_ notification: NSNotification) {
        guard let ringId = notification.userInfo?[ProfileNotificationsKeys.ringID.rawValue] as? String else {
            return
        }

        guard let message = notification.userInfo?[ProfileNotificationsKeys.message.rawValue] as? [String: String] else {
            return
        }

        guard let accountId = notification.userInfo?[ProfileNotificationsKeys.accountId.rawValue] as? String else {
            return
        }

        if let vCardKey = message.keys.filter({ $0.hasPrefix(self.ringVCardMIMEType) }).first {

            //Parse the key to get the number of parts and the current part number
            let components = vCardKey.components(separatedBy: ",")

            guard let partComponent = components.filter({$0.hasPrefix("part=")}).first else {
                return
            }

            guard let ofComponent = components.filter({$0.hasPrefix("of=")}).first else {
                return
            }

            guard let idComponent = components.filter({$0.hasPrefix("x-ring/ring.profile.vcard;id=")}).first else {
                return
            }

            guard let part = Int(partComponent.components(separatedBy: "=")[1]) else {
                return
            }

            guard let of = Int(ofComponent.components(separatedBy: "=")[1]) else {
                return
            }

            guard let id = Int(idComponent.components(separatedBy: "=")[1]) else {
                return
            }
            var numberOfReceivedChunk = 1
            if var chunk = self.base64VCards[id] {
                chunk.data[part] = message[vCardKey]
                chunk.partsReceived += 1
                numberOfReceivedChunk = chunk.partsReceived
                self.base64VCards[id] = chunk
            } else {
                let partMessage = message[vCardKey]
                let data: [Int: String] = [part: partMessage!]
                let chunk = Base64VCard(data: data, partsReceived: numberOfReceivedChunk)
                self.base64VCards[id] = chunk
            }

            //Build the vCard when all data are appended
            if of == numberOfReceivedChunk {
                self.buildVCardFromChunks(cardID: id, ringID: ringId, accountId: accountId)
            }
        }
    }

    private func buildVCardFromChunks(cardID: Int, ringID: String, accountId: String) {
        guard let vcard = self.base64VCards[cardID] else {
            return
        }

        let vCardChunks = vcard.data

        //Append data from sorted part numbers
        var vCardData = Data()
        for currentPartNumber in vCardChunks.keys.sorted() {
            if let currentData = vCardChunks[currentPartNumber]?.data(using: String.Encoding.utf8) {
                vCardData.append(currentData)
            }
        }

        //Create the vCard, save and db and emit a new event
        if let vCard = CNContactVCardSerialization.parseToVCard(data: vCardData) {
            let name = VCardUtils.getName(from: vCard)
            var stringImage: String?
            if let image = vCard.imageData {
                stringImage = image.base64EncodedString()
            }
            let uri = ringID.replacingOccurrences(of: "@ring.dht", with: "")
            _ = self.dbManager
                .createOrUpdateRingProfile(profileUri: uri,
                                           alias: name,
                                           image: stringImage,
                                           status: ProfileStatus.untrasted,
                                           accountId: accountId,
                                           isAccount: false)
            self.updateProfileFor(ringId: uri)
        }
    }

    private func addOrUpdatePrifileFor(ringId: String, accountId: String, isAccount: Bool) {
        guard let profileObservable = self.profiles[ringId] else {
            return
        }
        self.dbManager
            .addAndGetProfileObservable(for: ringId, accountId: accountId, isAccount: isAccount)
            .subscribe(onNext: {profile in
                profileObservable.onNext(profile)
            }).disposed(by: self.disposeBag)
    }

    private func updateProfileFor(ringId: String) {
        guard let profileObservable = self.profiles[ringId] else {
            return
        }
        self.dbManager
            .getProfileObservable(for: ringId)
            .subscribe(onNext: {profile in
                profileObservable.onNext(profile)
            }).disposed(by: self.disposeBag)
    }

    func addAndGetProfile(ringId: String,
                          accountId: String,
                          isAccount: Bool) -> Observable<Profile> {
        if let profile = self.profiles[ringId] {
            return profile.asObservable().share()
        }
        let profileObservable = ReplaySubject<Profile>.create(bufferSize: 1)
        self.profiles[ringId] = profileObservable
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.addOrUpdatePrifileFor(ringId: ringId, accountId: accountId, isAccount: isAccount)
        }
        return profileObservable.share()
    }

    func getProfile(ringId: String) -> Observable<Profile> {
        if let profile = self.profiles[ringId] {
            return profile.asObservable().share()
        }
        let profileObservable = ReplaySubject<Profile>.create(bufferSize: 1)
        self.profiles[ringId] = profileObservable
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.updateProfileFor(ringId: ringId)
        }
        return profileObservable.share()
    }
}
