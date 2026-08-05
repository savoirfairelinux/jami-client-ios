/*
 * Copyright (C) 2019-2026 Savoir-faire Linux Inc.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA.
 */

import Foundation
import RxSwift
import RxRelay

final class CallParticipantAvatars {

    let accountId: String
    private let profileService: ProfilesService
    private let nameService: NameService
    private let localParticipantHash: String
    private var providers: [String: AvatarProvider] = [:]
    /// Spelling-keyed shortcut: callers ask from view bodies, and canonicalizing a uri
    /// costs a regex and several allocations that the profile key would only discard.
    private var providersByURI: [String: AvatarProvider] = [:]
    private let disposeBag = DisposeBag()

    init(accountId: String,
         profileService: ProfilesService,
         nameService: NameService,
         localJamiId: String) {
        self.accountId = accountId
        self.profileService = profileService
        self.nameService = nameService
        self.localParticipantHash = Self.participantKey(for: localJamiId).hash
    }

    func provider(forUri uri: String) -> AvatarProvider {
        if let existing = providersByURI[uri] { return existing }
        let key = Self.participantKey(for: uri)
        let provider = providers[key.profileUri] ?? makeProvider(key: key)
        providers[key.profileUri] = provider
        providersByURI[uri] = provider
        return provider
    }

    private func makeProvider(key: (profileUri: String, hash: String)) -> AvatarProvider {
        let hash = key.hash
        let isLocal = !localParticipantHash.isEmpty && hash == localParticipantHash
        let profileNameRelay = BehaviorRelay(value: "")
        let registeredNameRelay = BehaviorRelay(value: "")

        let source = isLocal
            ? profileService.getAccountProfile(accountId: accountId)
            : profileService.getProfile(uri: key.profileUri,
                                        createIfNotexists: false,
                                        accountId: accountId)
        let profile = source.share(replay: 1)

        let photo: Observable<Data?> = profile.map { $0.photo?.toImageData() }
        profile
            .map { $0.alias ?? "" }
            .subscribe(onNext: { profileNameRelay.accept($0) })
            .disposed(by: disposeBag)

        resolveRegisteredName(forHash: hash, into: registeredNameRelay)

        let name = Observable
            .combineLatest(registeredNameRelay.asObservable(),
                           profileNameRelay.asObservable()) { registered, profileName in
                ContactsUtils.getFinalNameFrom(registeredName: registered,
                                               profileName: profileName,
                                               hash: hash)
            }
            .distinctUntilChanged()
            .observe(on: MainScheduler.instance)
            .share(replay: 1)

        return AvatarProvider(profileService: profileService,
                              size: Constants.AvatarSize.call160,
                              avatar: photo,
                              displayName: name,
                              isGroup: false,
                              waitForFirstAvatar: true,
                              isLocalParticipant: isLocal)
    }

    private func resolveRegisteredName(forHash hash: String,
                                       into relay: BehaviorRelay<String>) {
        nameService.usernameLookupStatus
            .filter { $0.address == hash || $0.requestedName == hash }
            .compactMap { response -> String? in
                guard let name = response.name, !name.isEmpty else { return nil }
                return name
            }
            .take(1)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { relay.accept($0) })
            .disposed(by: disposeBag)
        nameService.lookupAddress(withAccount: accountId, nameserver: "", address: hash)
    }

    static func participantKey(for uri: String) -> (profileUri: String, hash: String) {
        let parsed = JamiURI(from: uri)
        return (parsed.uriString ?? uri, parsed.hash ?? uri)
    }

    static func avatarSize(forTileSide side: CGFloat) -> CGFloat {
        min(max(side * 0.4, 44), 140)
    }
}
