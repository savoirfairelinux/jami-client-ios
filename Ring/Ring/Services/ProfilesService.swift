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
    private var jamsSearchProfiles: ThreadSafeDictionary<ProfileKey, Profile>
    private var profileVersions: ThreadSafeDictionary<ProfileKey, Int>
    var accountProfiles: ThreadSafeDictionary<String, ReplaySubject<Profile>>

    private let avatarsCache = NSCache<NSString, UIImage>()

    private let profileStore: ProfileStore

    // Shared scheduler for profile resolution so we don't allocate a new
    // background queue on every resolution request.
    private let resolutionScheduler = ConcurrentDispatchQueueScheduler(qos: .background)

    let disposeBag = DisposeBag()

    init(withProfilesAdapter adapter: ProfilesAdapter,
         profileStore: ProfileStore = ProfileStore()) {
        self.profiles = ThreadSafeDictionary(lock: profilesLock)
        self.jamsSearchProfiles = ThreadSafeDictionary(lock: profilesLock)
        self.profileVersions = ThreadSafeDictionary(lock: profilesLock)
        self.accountProfiles = ThreadSafeDictionary(lock: profilesLock)
        self.profilesAdapter = adapter
        self.profileStore = profileStore
        avatarsCache.totalCostLimit = 8 * 1024 * 1024
    }

    func profileReceived(contact uri: String, withAccountId accountId: String, path: String) {
        guard let uriString = JamiURI(schema: URIType.ring, infoHash: uri).uriString else { return }
        removePeerProfiles(uri: uriString, accountId: accountId)
        self.triggerProfileSignal(uri: uriString, accountId: accountId)
    }

    func cacheJamsSearchProfile(uri: String, accountId: String, alias: String?, photo: String?) {
        let uri = normalizedURI(uri)
        let profile = Profile(uri: uri, alias: alias, photo: photo, type: ProfileType.ring.rawValue)
        guard !profile.isEmpty else { return }
        jamsSearchProfiles[ProfileKey(accountId: accountId, uri: uri)] = profile
        triggerProfileSignal(uri: uri, accountId: accountId)
    }

    func invitationAccepted(_ profile: Profile, accountId: String) {
        profileStore.save(profile, accountId: accountId, source: .invitation)
        triggerProfileSignal(uri: profile.uri, accountId: accountId)
    }

    func invitationSent(uri: String, accountId: String) {
        let uri = normalizedURI(uri)
        if let profile = jamsSearchProfiles[ProfileKey(accountId: accountId, uri: uri)] {
            profileStore.save(profile, accountId: accountId, source: .jamsSearch)
        }
        triggerProfileSignal(uri: uri, accountId: accountId)
    }

    func peerDiscarded(uri: String, accountId: String) {
        removePeerProfiles(uri: uri, accountId: accountId)
        triggerProfileSignal(uri: uri, accountId: accountId)
    }

    func conversationDeleted(uri: String, accountId: String) {
        let uri = normalizedURI(uri)
        jamsSearchProfiles.removeValue(forKey: ProfileKey(accountId: accountId, uri: uri))
        profileStore.removeManagedProfiles(uri: uri, accountId: accountId)
        triggerProfileSignal(uri: uri, accountId: accountId)
    }

    func accountContactsCleared(accountId: String) {
        for key in jamsSearchProfiles.keys where key.accountId == accountId {
            jamsSearchProfiles.removeValue(forKey: key)
        }
        profileStore.removeAllManagedProfiles(accountId: accountId)
    }

    private func triggerProfileSignal(uri: String, accountId: String) {
        let uri = normalizedURI(uri)
        let key = ProfileKey(accountId: accountId, uri: uri)
        guard let profileObservable = self.profiles[key] else {
            return
        }
        let version = profileVersions.mutate { versions -> Int in
            let next = (versions[key] ?? 0) + 1
            versions[key] = next
            return next
        }
        Observable.deferred { [weak self] () -> Observable<Profile> in
            guard let self else { return .just(Profile.empty) }
            return .just(self.resolveProfile(for: key))
        }
            .subscribe(on: self.resolutionScheduler)
            .subscribe(onNext: { [weak self] profile in
                guard self?.profileVersions[key] == version else { return }
                profileObservable.onNext(profile)
            })
            .disposed(by: self.disposeBag)
    }

    func getProfile(uri: String, accountId: String) -> Observable<Profile> {
        let uri = normalizedURI(uri)
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

    private func resolveProfile(for key: ProfileKey) -> Profile {
        let localOverride = profileStore.profile(uri: key.uri, accountId: key.accountId, source: .localOverride)
        let peerProfile = profileStore.profile(uri: key.uri, accountId: key.accountId, source: .contact)
            ?? profileStore.legacyContactProfile(uri: key.uri, accountId: key.accountId)
            ?? jamsSearchProfile(for: key)
            ?? invitationProfile(for: key)
        return peerProfile?.merging(preferring: localOverride) ?? localOverride ?? Profile.empty
    }

    private func jamsSearchProfile(for key: ProfileKey) -> Profile? {
        jamsSearchProfiles[key]
            ?? profileStore.profile(uri: key.uri, accountId: key.accountId, source: .jamsSearch)
    }

    private func invitationProfile(for key: ProfileKey) -> Profile? {
        profileStore.profile(uri: key.uri, accountId: key.accountId, source: .invitation)
    }

    private func removePeerProfiles(uri: String, accountId: String) {
        let uri = normalizedURI(uri)
        jamsSearchProfiles.removeValue(forKey: ProfileKey(accountId: accountId, uri: uri))
        profileStore.remove(uri: uri, accountId: accountId, source: .jamsSearch)
        profileStore.remove(uri: uri, accountId: accountId, source: .invitation)
    }

    private func normalizedURI(_ uri: String) -> String {
        JamiURI(from: uri).uriString ?? uri
    }

    func getProfileWithoutLocalOverride(uri: String, accountId: String) -> Profile? {
        let uri = normalizedURI(uri)
        return profileStore.profile(uri: uri, accountId: accountId, source: .contact)
            ?? profileStore.legacyContactProfile(uri: uri, accountId: accountId)
    }

    func getLocalProfileOverride(uri: String, accountId: String) -> Profile? {
        profileStore.profile(uri: normalizedURI(uri), accountId: accountId, source: .localOverride)
    }

    @discardableResult
    func updateLocalProfileOverride(uri: String,
                                    accountId: String,
                                    alias: String?,
                                    photo: String?) -> Bool {
        let uri = normalizedURI(uri)
        let type = uri.contains("ring") ? ProfileType.ring : ProfileType.sip
        let profile = Profile(uri: uri, alias: alias, photo: photo, type: type.rawValue)
        let saved: Bool
        if profile.isEmpty {
            profileStore.remove(uri: uri, accountId: accountId, source: .localOverride)
            saved = true
        } else {
            saved = profileStore.save(profile, accountId: accountId, source: .localOverride)
        }
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
        Observable.deferred { [weak self] () -> Observable<Profile> in
            guard let self else { return .just(Profile.empty) }
            return .just(self.profileStore.accountProfile(accountId: accountId) ?? Profile.empty)
        }
            .subscribe(on: self.resolutionScheduler)
            .subscribe(onNext: { profile in
                profileObservable.onNext(profile)
            })
            .disposed(by: self.disposeBag)
    }

    /// The account's own vCard, as sent with an outgoing trust request.
    /// Nil when the user never set a name or a picture.
    func accountVCardPayload(accountId: String) -> Data? {
        guard let profile = profileStore.accountProfile(accountId: accountId),
              !profile.isEmpty else { return nil }
        return try? VCardUtils.dataWithImageAndUUID(from: profile)
    }

    func accountProfileUpdated(accountId: String) {
        self.triggerAccountProfileSignal(accountId: accountId)
    }

    func updateAccountProfile(accountId: String, alias: String?, photo: String?, accountURI: String) {
        let type = accountURI.contains("ring") ? ProfileType.ring : ProfileType.sip
        let profile = Profile(uri: accountURI, alias: alias, photo: photo, type: type.rawValue)
        if self.profileStore.saveAccountProfile(profile, accountId: accountId) {
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
