/*
 *  Copyright (C) 2017-2025 Savoir-faire Linux Inc.
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

import RxSwift
import SwiftyBeaver
import CryptoKit

@objc protocol ProfilesAdapterDelegate {
    func profileReceived(contact uri: String, withAccountId accountId: String, path: String)
}

private struct ProfileKey: Hashable {
    let accountId: String
    let uri: String
}

class ProfilesService {

    private let log = SwiftyBeaver.self
    private let profilesAdapter: ProfilesAdapter

    private let profilesLock = NSLock()
    private var profiles: ThreadSafeDictionary<ProfileKey, ReplaySubject<Profile>>
    private var directoryProfiles: ThreadSafeDictionary<ProfileKey, Profile>
    var accountProfiles: ThreadSafeDictionary<String, ReplaySubject<Profile>>

    private let avatarsCache = NSCache<NSString, UIImage>()

    let dbManager: DBManager

    // Shared scheduler for profile resolution so we don't allocate a new
    // background queue on every resolution request.
    private let resolutionScheduler = ConcurrentDispatchQueueScheduler(qos: .background)

    let disposeBag = DisposeBag()

    init(withProfilesAdapter adapter: ProfilesAdapter, dbManager: DBManager) {
        self.profiles = ThreadSafeDictionary(lock: profilesLock)
        self.directoryProfiles = ThreadSafeDictionary(lock: profilesLock)
        self.accountProfiles = ThreadSafeDictionary(lock: profilesLock)
        profilesAdapter = adapter
        self.dbManager = dbManager
        avatarsCache.totalCostLimit = 8 * 1024 * 1024
    }

    func profileReceived(contact uri: String, withAccountId accountId: String, path: String) {
        guard let uriString = JamiURI(schema: URIType.ring, infoHash: uri).uriString else { return }
        self.triggerProfileSignal(uri: uriString, accountId: accountId)
    }

    func cacheDirectoryProfile(uri: String, accountId: String, alias: String?, photo: String?) {
        let profile = Profile(uri: uri, alias: alias, photo: photo, type: ProfileType.ring.rawValue)
        guard !profile.isEmpty else { return }
        directoryProfiles[ProfileKey(accountId: accountId, uri: uri)] = profile
        triggerProfileSignal(uri: uri, accountId: accountId)
    }

    private func triggerProfileSignal(uri: String, accountId: String) {
        let key = ProfileKey(accountId: accountId, uri: uri)
        guard let profileObservable = self.profiles[key] else {
            return
        }
        let directoryProfile = directoryProfiles[key]
        self.dbManager
            .profileObservable(for: uri, accountId: accountId)
            .subscribe(on: self.resolutionScheduler)
            .subscribe { profile in
                profileObservable.onNext(directoryProfile?.merging(preferring: profile) ?? profile)
            } onError: { [weak self] error in
                // Emit an empty profile instead of erroring so the cached subject stays alive for a later real profile.
                self?.log.debug("No profile for \(uri): \(error). Emitting empty placeholder.")
                profileObservable.onNext(directoryProfile ?? Profile.empty)
            }
            .disposed(by: self.disposeBag)
    }

    func getProfile(uri: String, accountId: String) -> Observable<Profile> {
        let (subject, inserted) = profiles.getOrInsert(key: ProfileKey(accountId: accountId, uri: uri)) {
            ReplaySubject<Profile>.create(bufferSize: 1)
        }
        if inserted {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.triggerProfileSignal(uri: uri, accountId: accountId)
            }
        }
        return subject.asObservable().share()
    }

    func getProfileWithoutLocalOverride(uri: String, accountId: String) -> Profile? {
        dbManager.getProfileWithoutLocalOverride(for: uri, accountId: accountId)
    }

    func getLocalProfileOverride(uri: String, accountId: String) -> Profile? {
        dbManager.localProfileOverride(for: uri, accountId: accountId)
    }

    @discardableResult
    func updateLocalProfileOverride(uri: String,
                                    accountId: String,
                                    alias: String?,
                                    photo: String?) -> Bool {
        let saved = dbManager.saveLocalProfileOverride(profileUri: uri,
                                                       alias: alias,
                                                       photo: photo,
                                                       accountId: accountId)
        if saved {
            triggerProfileSignal(uri: uri, accountId: accountId)
        }
        return saved
    }
}

// MARK: account profile
extension ProfilesService {
    func getAccountProfile(accountId: String) -> Observable<Profile> {
        let (subject, inserted) = accountProfiles.getOrInsert(key: accountId) {
            ReplaySubject<Profile>.create(bufferSize: 1)
        }
        if inserted {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.triggerAccountProfileSignal(accountId: accountId)
            }
        }
        return subject.asObservable().share()
    }

    private func triggerAccountProfileSignal(accountId: String) {
        guard let profileObservable = self.accountProfiles[accountId] else {
            return
        }
        self.dbManager
            .accountProfileObservable(for: accountId)
            .subscribe(on: self.resolutionScheduler)
            .subscribe(onNext: { profile in
                profileObservable.onNext(profile)
            }, onError: { [weak self] error in
                self?.log.debug("No account profile for \(accountId): \(error). Emitting empty placeholder.")
                profileObservable.onNext(Profile.empty)
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

    func key(for data: Data, size: CGFloat) -> String {
        let digest = SHA256.hash(data: data)
        let hex = digest.compactMap { String(format: "%02x", $0) }.joined()
        return "\(hex)|\(Int(size))"
    }

    subscript(_ key: String) -> UIImage? {
        get { avatarsCache.object(forKey: key as NSString) }
        set {
            if let img = newValue {
                let cost = Int(img.size.width * img.size.height * img.scale * img.scale * 4)
                avatarsCache.setObject(img, forKey: key as NSString, cost: cost)
            } else { avatarsCache.removeObject(forKey: key as NSString) }
        }
    }

    func getAvatarFor(_ data: Data, size: CGFloat) -> UIImage? {
        let key = key(for: data, size: size)
        if let cached = self[key] {
            return cached
        }
        let image: UIImage? = data.convertToImage(size: size)
        if let image = image,
           size == Constants.defaultAvatarSize * 2 {
            self[key] = image
        }
        return image
    }
}
