/*
 *  Copyright (C) 2016-2025 Savoir-faire Linux Inc.
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

import UIKit
import SwiftUI
import RxSwift
import RxRelay

class AvatarView: UIView {
    init(profileImageData: Data?,
         username: String,
         isGroup: Bool,
         size: CGFloat = 32.0,
         offset: CGPoint = .zero,
         labelFontSize: CGFloat? = nil) {

        let frame = CGRect(x: 0, y: 0, width: size, height: size)
        super.init(frame: frame)

        if let imageData = profileImageData, !imageData.isEmpty,
           let image = UIImage(data: imageData) {
            let imageView = UIImageView(frame: frame)
            imageView.image = image
            imageView.layer.cornerRadius = size / 2
            imageView.clipsToBounds = true
            imageView.contentMode = .scaleAspectFill
            addSubview(imageView)
        } else {
            let bgColor = avatarBackgroundColor(for: username)
            let centerPoint = CGPoint(x: size / 2, y: size / 2)

            let circle = UIView(frame: CGRect(x: offset.x, y: offset.y, width: size, height: size))
            circle.center = centerPoint
            circle.layer.cornerRadius = size / 2
            circle.backgroundColor = bgColor
            circle.clipsToBounds = true
            addSubview(circle)

            if !username.isSHA1() && !username.isEmpty && !isGroup {
                let label = UILabel(frame: CGRect(x: offset.x, y: offset.y, width: size, height: size))
                label.center = centerPoint
                label.text = username.prefixString().capitalized
                label.font = UIFont.systemFont(ofSize: labelFontSize ?? AvatarMetrics.monogramFontSize(for: size), weight: .semibold)
                label.textColor = .white
                label.textAlignment = .center
                addSubview(label)
            } else {
                let symbolSize = AvatarMetrics.iconSize(for: size)
                let config = UIImage.SymbolConfiguration(pointSize: symbolSize, weight: .semibold)
                let symbolName = isGroup ? "person.2.fill" : "person.fill"
                if let image = UIImage(systemName: symbolName, withConfiguration: config) {
                    let iconView = UIImageView(frame: frame)
                    iconView.image = image
                    iconView.tintColor = .white
                    iconView.contentMode = .center
                    addSubview(iconView)
                }
            }
        }
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}

class AvatarProvider: ObservableObject {
    @Published var avatar: UIImage?
    @Published var profileName: String = ""
    @Published var registeredName: String = ""
    @Published private(set) var isGroup: Bool = false
    @Published var jamiId: String = ""
    @Published var displayParticipants: [ParticipantInfo] = []
    @Published var overflowCount: Int = 0
    @Published var hasCustomAvatar: Bool = false
    @Published var groupAvatarSnapshot: UIImage?
    let size: Constants.AvatarSize

    private let profileService: ProfilesService
    private let disposeBag = DisposeBag()
    private var snapshotBag = DisposeBag()
    private var hasReceivedParticipants = false

    init(profileService: ProfilesService,
         size: Constants.AvatarSize,
         avatar avatarStream: Observable<Data?>,
         displayName nameStream: Observable<String>,
         isGroup: Bool) {
        self.size = size
        self.profileService = profileService
        self.subscribeAvatar(observable: avatarStream)
        self.subscribeProfileName(observable: nameStream.map { Optional($0) })
        self.isGroup = isGroup
    }

    init(profileService: ProfilesService,
         size: Constants.AvatarSize) {
        self.size = size
        self.profileService = profileService
    }

    private func subscribeAvatar(observable: Observable<Data?>) {
        observable
            .compactMap { $0 }
            .distinctUntilChanged()
            .observe(on: ConcurrentDispatchQueueScheduler(qos: .userInitiated))
            .map { [weak self] data -> UIImage? in
                guard let self = self else { return nil }
                let decodeSize = max(self.size.points * 2, Constants.defaultAvatarSize * 2)
                return self.profileService.getAvatarFor(data, size: decodeSize)
            }
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] image in
                self?.avatar = image
            })
            .disposed(by: disposeBag)
    }

    private func subscribeProfileName(observable: Observable<String?>) {
        observable
            .compactMap { $0 }
            .distinctUntilChanged()
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] name in
                self?.profileName = name
            })
            .disposed(by: disposeBag)
    }

    private func subscribeGroupParticipants(swarmInfo: SwarmInfoProtocol) {
        swarmInfo.avatarData.asObservable()
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] data in
                self?.hasCustomAvatar = data.map({ !$0.isEmpty }) ?? false
            })
            .disposed(by: disposeBag)

        Observable.combineLatest(
            swarmInfo.participants.asObservable(),
            swarmInfo.participantsAvatars.asObservable()
        )
        .observe(on: MainScheduler.instance)
        .subscribe(onNext: { [weak self] (participants, _) in
            self?.updateDisplay(participants: participants)
        })
        .disposed(by: disposeBag)
    }

    private func updateDisplay(participants: [ParticipantInfo]) {
        let candidates = participants.map { participant in
            GroupAvatarCandidate(
                member: GroupAvatarMember(image: participant.provider.avatar, name: participant.finalName.value),
                role: participant.role
            )
        }
        let selection = GroupAvatarRenderer.selectForDisplay(from: candidates)
        let visible = selection.selectedIndices.map { participants[$0] }

        let visibleIds = visible.map { $0.jamiId }
        let currentIds = displayParticipants.map { $0.jamiId }
        let isFirstUpdate = !hasReceivedParticipants && !participants.isEmpty
        hasReceivedParticipants = hasReceivedParticipants || !participants.isEmpty
        guard visibleIds != currentIds || selection.overflowCount != overflowCount || isFirstUpdate else { return }
        self.displayParticipants = visible
        self.overflowCount = selection.overflowCount
        renderGroupSnapshot()
        subscribeVisibleParticipantsForSnapshot()
    }

    private func subscribeVisibleParticipantsForSnapshot() {
        snapshotBag = DisposeBag()
        let participants = displayParticipants
        guard !participants.isEmpty else { return }

        let observables = participants.map { participant in
            Observable.merge(
                participant.avatarData.asObservable().map { _ in },
                participant.finalName.asObservable().skip(1).map { _ in }
            )
        }

        Observable.merge(observables)
            .debounce(.milliseconds(50), scheduler: MainScheduler.instance)
            .subscribe(onNext: { [weak self] in
                self?.renderGroupSnapshot()
            })
            .disposed(by: snapshotBag)
    }

    func renderGroupSnapshot() {
        dispatchPrecondition(condition: .onQueue(.main))
        let members = displayParticipants.map { participant in
            GroupAvatarMember(image: participant.provider.avatar,
                              name: participant.finalName.value)
        }
        groupAvatarSnapshot = GroupAvatarRenderer.render(
            members: members,
            overflowCount: overflowCount,
            totalSize: size.points
        )
    }

}

// MARK: - Builders for common contexts
extension AvatarProvider {
    static func from(participant: ParticipantInfo, size: Constants.AvatarSize) -> AvatarProvider {
        return AvatarProvider(
            profileService: participant.profileService,
            size: size,
            avatar: participant.avatarData.asObservable(),
            displayName: participant.finalName.asObservable(),
            isGroup: false
        )
    }

    static func from(swarmInfo: SwarmInfoProtocol, profileService: ProfilesService, size: Constants.AvatarSize) -> AvatarProvider {
        let isGroup = !(swarmInfo.conversation?.isCoredialog() ?? false)
        let provider = AvatarProvider(
            profileService: profileService,
            size: size,
            avatar: swarmInfo.finalAvatarData,
            displayName: swarmInfo.finalTitle.asObservable(),
            isGroup: isGroup
        )
        if isGroup {
            provider.subscribeGroupParticipants(swarmInfo: swarmInfo)
        }
        return provider
    }
}

struct AvatarSwiftUIView: View {
    @ObservedObject var source: AvatarProvider
    @Environment(\.colorScheme) var colorScheme
    var sizeOverride: CGFloat?

    private var effectiveSize: CGFloat { sizeOverride ?? source.size.points }

    var body: some View {
        if source.isGroup && !source.hasCustomAvatar, let snapshot = source.groupAvatarSnapshot {
            Image(uiImage: snapshot)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fill)
                .frame(width: effectiveSize, height: effectiveSize)
                .clipShape(Circle())
                .fixedSize()
                .onChange(of: colorScheme) { _ in
                    source.renderGroupSnapshot()
                }
        } else {
            singleAvatarView
        }
    }

    private var singleAvatarView: some View {
        ZStack {
            if let image = source.avatar {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.none)
                    .aspectRatio(contentMode: .fill)
            } else {
                monogramView
            }
        }
        .frame(width: effectiveSize, height: effectiveSize)
        .clipShape(Circle())
        .fixedSize()
    }

    @ViewBuilder private var monogramView: some View {
        let displayText = resolvedDisplayText
        let bgColor = avatarBackgroundColor(for: displayText)
        let borderColor = Color(bgColor.darker(by: 1) ?? bgColor)

        ZStack {
            Color(bgColor)
            Circle()
                .stroke(borderColor, lineWidth: AvatarMetrics.borderWidth)

            if !displayText.isSHA1() && !displayText.isEmpty && !source.isGroup {
                Text(String(displayText.prefix(1)).uppercased())
                    .font(.system(size: AvatarMetrics.monogramFontSize(for: effectiveSize), weight: .semibold))
                    .foregroundColor(.white)
            } else {
                Image(systemName: source.isGroup ? "person.2.fill" : "person.fill")
                    .font(.system(size: AvatarMetrics.iconSize(for: effectiveSize), weight: .semibold))
                    .foregroundColor(.white)
            }
        }
    }

    private var resolvedDisplayText: String {
        if !source.profileName.isEmpty { return source.profileName }
        if !source.registeredName.isEmpty { return source.registeredName }
        return source.jamiId
    }

}

protocol AvatarRelayProviding: AnyObject {
    func avatarRelay(for jamiId: String) -> BehaviorRelay<Data?>
    func nameRelay(for jamiId: String) -> BehaviorRelay<String>
}

final class AvatarProviderFactory {
    private let relayProvider: AvatarRelayProviding
    private let profileService: ProfilesService
    private var cache: [String: AvatarProvider] = [:] // key: "<jamiId>|<Int(size)>"

    init(relayProvider: AvatarRelayProviding, profileService: ProfilesService) {
        self.relayProvider = relayProvider
        self.profileService = profileService
    }

    func provider(for jamiId: String, size: Constants.AvatarSize) -> AvatarProvider {
        let key = "\(jamiId)|\(Int(size.points))"
        if let existing = cache[key] { return existing }
        let provider = AvatarProvider(
            profileService: profileService,
            size: size,
            avatar: relayProvider.avatarRelay(for: jamiId).asObservable(),
            displayName: relayProvider.nameRelay(for: jamiId).asObservable(),
            isGroup: false
        )
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
