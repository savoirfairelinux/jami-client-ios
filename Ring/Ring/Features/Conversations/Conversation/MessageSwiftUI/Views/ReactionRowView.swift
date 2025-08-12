/*
 *  Copyright (C) 2023-2024 Savoir-faire Linux Inc.
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

import SwiftUI
import RxRelay


struct ReactionRowView: View {
    @ObservedObject var reaction: ReactionsRowViewModel
    @Environment(\.avatarProviderFactory) var avatarFactory: AvatarProviderFactory?
    let padding: CGFloat = 20

    var body: some View {
        HStack {
            if let factory = avatarFactory {
                AvatarSwiftUIView(source: factory.provider(for: reaction.jamiId, size: 40))
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
            }
            Spacer()
                .frame(width: padding)

            Text(reaction.username)
                .font(.callout)
                .lineLimit(1)
                .truncationMode(.tail)
                .layoutPriority(0.5)
                .multilineTextAlignment(.leading)

            Spacer()

            ScrollView {
                Text(reaction.toString())
                    .bold()
                    .font(.title3)
                    .lineLimit(nil)
                    .multilineTextAlignment(.trailing)
            }
            .frame(maxHeight: 60)
            .frame(minWidth: 30)
            .layoutPriority(0.5)
        }
        .padding(.horizontal, padding)
    }
}

protocol AvatarRelayProviding: AnyObject {
    func avatarRelay(for jamiId: String) -> BehaviorRelay<Data?>
    func nameRelay(for jamiId: String) -> BehaviorRelay<String>
}

// ViewModel exposes a factory built on itself (the relay provider)
//extension MessagesListVM: AvatarRelayProviding {
//    func makeAvatarFactory() -> AvatarProviderFactory
//}

final class AvatarProviderFactory {
    private let relayProvider: AvatarRelayProviding
    private let profileService: ProfilesService
    private var cache: [String: AvatarProvider] = [:] // key: "<jamiId>|<Int(size)>"

    init(relayProvider: AvatarRelayProviding, profileService: ProfilesService) {
        self.relayProvider = relayProvider
        self.profileService = profileService
    }

    func provider(for jamiId: String, size: CGFloat) -> AvatarProvider {
        let key = "\(jamiId)|\(Int(size))"
        if let existing = cache[key] { return existing }
        let provider = AvatarProvider(profileService: profileService, size: size)
        provider.subscribeAvatar(observable: relayProvider.avatarRelay(for: jamiId).asObservable())
        provider.subscribeProfileName(observable: relayProvider.nameRelay(for: jamiId).asObservable())
        cache[key] = provider
        return provider
    }
}

private struct AvatarProviderFactoryKey: EnvironmentKey {
    static let defaultValue: AvatarProviderFactory? = nil
}

extension EnvironmentValues {
    var avatarProviderFactory: AvatarProviderFactory? {
        get { self[AvatarProviderFactoryKey.self] }
        set { self[AvatarProviderFactoryKey.self] = newValue }
    }
}

