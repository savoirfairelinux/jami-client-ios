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

@objc protocol ProfilesAdapterDelegate {
    func profileReceived(contact uri: String, withAccountId accountId: String, path: String)
}

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
    var data: [Int: String] // The key is the number of vCard part
    var partsReceived: Int
}

class ProfilesService {

    private let ringVCardMIMEType = "x-ring/ring.profile.vcard;"
    private var base64VCards = [Int: Base64VCard]()
    private let log = SwiftyBeaver.self
    private let profilesAdapter: ProfilesAdapter

    var profiles = ConcurentDictionary(name: "com.contactProfiles", dictionary: [String: ReplaySubject<Profile>]())
    var accountProfiles = ConcurentDictionary(name: "com.accountProfiles", dictionary: [String: ReplaySubject<Profile>]())

    let dbManager: DBManager

    let disposeBag = DisposeBag()

    init(withProfilesAdapter adapter: ProfilesAdapter, dbManager: DBManager) {
        profilesAdapter = adapter
        self.dbManager = dbManager
        NotificationCenter.default.addObserver(self, selector: #selector(self.messageReceived(_:)),
                                               name: NSNotification.Name(rawValue: ProfileNotifications.messageReceived.rawValue),
                                               object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.contactAdded(_:)),
                                               name: NSNotification.Name(rawValue: ProfileNotifications.contactAdded.rawValue),
                                               object: nil)
    }

    func profileReceived(contact uri: String, withAccountId accountId: String, path: String) {
        let uri = JamiURI(schema: URIType.ring, infoHash: uri)
        guard let uriString = uri.uriString,
              let profile = VCardUtils.parseToProfile(filePath: path) else { return }
        _ = self.dbManager
            .createOrUpdateRingProfile(profileUri: uriString,
                                       alias: profile.alias,
                                       image: profile.photo,
                                       accountId: accountId)
        self.triggerProfileSignal(uri: uriString, createIfNotexists: false, accountId: accountId)
    }

    @objc
    private func contactAdded(_ notification: NSNotification) {
        guard let ringId = notification.userInfo?[ProfileNotificationsKeys.ringID.rawValue] as? String else {
            return
        }
        guard let accountId = notification.userInfo?[ProfileNotificationsKeys.accountId.rawValue] as? String else {
            return
        }

        let uri = JamiURI(schema: URIType.ring, infoHash: ringId)
        let uriString = uri.uriString ?? ringId
        self.triggerProfileSignal(uri: uriString, createIfNotexists: false, accountId: accountId)
    }

    @objc
    private func messageReceived(_ notification: NSNotification) {
        guard let ringId = notification.userInfo?[ProfileNotificationsKeys.ringID.rawValue] as? String else {
            return
        }

        guard let message = notification.userInfo?[ProfileNotificationsKeys.message.rawValue] as? [String: String] else {
            return
        }

        guard let accountId = notification.userInfo?[ProfileNotificationsKeys.accountId.rawValue] as? String else {
            return
        }

        if let vCardKey = message.keys.filter({ $0.hasPrefix(self.ringVCardMIMEType) }).first,
           let decoded = vCardKey.removingPercentEncoding {

            guard let regex = try? NSRegularExpression(pattern: "x-ring/ring.profile.vcard;id=([A-z0-9]+),part=([0-9]+),of=([0-9]+)") else {
                return
            }
            let matches = regex.matches(in: decoded, range: NSRange(decoded.startIndex..., in: decoded))
            guard let match = matches.first,
                  let idRange = Range(match.range(at: 1), in: decoded),
                  let partRange = Range(match.range(at: 2), in: decoded),
                  let ofRange = Range(match.range(at: 3), in: decoded) else { return }

            let idString = String(decoded[idRange])
            let partString = String(decoded[partRange])
            let ofString = String(decoded[ofRange])

            guard let part = Int(partString),
                  let of = Int(ofString),
                  let id = Int(idString) else { return }

            var numberOfReceivedChunk = 1
            if var chunk = self.base64VCards[id] {
                chunk.data[part] = message[vCardKey]
                chunk.partsReceived += 1
                numberOfReceivedChunk = chunk.partsReceived
                self.base64VCards[id] = chunk
            } else {
                if let partMessage = message[vCardKey] {
                    let data: [Int: String] = [part: partMessage]
                    let chunk = Base64VCard(data: data, partsReceived: numberOfReceivedChunk)
                    self.base64VCards[id] = chunk
                }
            }

            // Build the vCard when all data are appended
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

        // Append data from sorted part numbers
        var vCardData = Data()
        for currentPartNumber in vCardChunks.keys.sorted() {
            if let currentData = vCardChunks[currentPartNumber]?.data(using: String.Encoding.utf8) {
                vCardData.append(currentData)
            }
        }

        // Create the vCard, save and db and emit a new event
        if let profile = VCardUtils.parseDataToProfile(data: vCardData) {
            guard let uri = JamiURI.init(schema: URIType.ring,
                                         infoHash: ringID).uriString else {
                return
            }
            _ = self.dbManager
                .createOrUpdateRingProfile(profileUri: uri,
                                           alias: profile.alias,
                                           image: profile.photo,
                                           accountId: accountId)
            self.triggerProfileSignal(uri: uri, createIfNotexists: false, accountId: accountId)
        }
    }

    private func triggerProfileSignal(uri: String, createIfNotexists: Bool, accountId: String) {
        guard let profileObservable = self.profiles.get(key: uri) as? ReplaySubject<Profile> else {
            return
        }
        self.dbManager
            .profileObservable(for: uri, createIfNotExists: createIfNotexists, accountId: accountId)
            .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
            .subscribe { profile in
                profileObservable.onNext(profile)
            } onError: { error in
                profileObservable.onError(error)
            }
            .disposed(by: self.disposeBag)
    }

    func getProfile(uri: String, createIfNotexists: Bool, accountId: String) -> Observable<Profile> {
        if let profile = self.profiles.get(key: uri) as? ReplaySubject<Profile> {
            return profile.asObservable().share()
        }
        let profileObservable = ReplaySubject<Profile>.create(bufferSize: 1)
        self.profiles.set(value: profileObservable, for: uri)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.triggerProfileSignal(uri: uri,
                                       createIfNotexists: createIfNotexists,
                                       accountId: accountId)
        }
        return profileObservable.share()
    }
}

// MARK: account profile
extension ProfilesService {
    func getAccountProfile(accountId: String) -> Observable<Profile> {
        if let profile = self.accountProfiles.get(key: accountId) as? ReplaySubject<Profile> {
            return profile.asObservable().share()
        }
        let profileObservable = ReplaySubject<Profile>.create(bufferSize: 1)
        self.accountProfiles.set(value: profileObservable, for: accountId)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.triggerAccountProfileSignal(accountId: accountId)
        }
        return profileObservable.share()
    }

    private func triggerAccountProfileSignal(accountId: String) {
        guard let profileObservable = self.accountProfiles.get(key: accountId) as? ReplaySubject<Profile> else {
            return
        }
        self.dbManager
            .accountProfileObservable(for: accountId)
            .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
            .subscribe(onNext: { profile in
                profileObservable.onNext(profile)
            }, onError: { (_) in
                profileObservable.onNext(Profile(uri: "", alias: nil, photo: nil, type: ""))
            })
            .disposed(by: self.disposeBag)
    }

    func accountProfileUpdated(accountId: String) {
        self.triggerAccountProfileSignal(accountId: accountId)
    }

    func updateAccountProfile(accountId: String, alias: String?, photo: String?, accountURI: String) {
        if self.dbManager
            .saveAccountProfile(alias: alias, photo: photo,
                                accountId: accountId, accountURI: accountURI) {
            self.triggerAccountProfileSignal(accountId: accountId)
        }
    }
}
