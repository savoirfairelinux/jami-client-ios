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

        let avatarImageView = UIImageView(frame: frame)
        if let imageData = profileImageData, !imageData.isEmpty,
           let image = UIImage(data: imageData) {
            avatarImageView.image = image
            avatarImageView.layer.cornerRadius = size / 2
            avatarImageView.clipsToBounds = true
            avatarImageView.contentMode = .scaleAspectFill
            addSubview(avatarImageView)
        } else {
            let bgColor = avatarBackgroundColor(for: username)

            let circle = UIView(frame: CGRect(x: offset.x, y: offset.y, width: size, height: size))
            circle.center = CGPoint(x: size / 2, y: center.y)
            circle.layer.cornerRadius = size / 2
            circle.backgroundColor = bgColor
            circle.clipsToBounds = true
            addSubview(circle)

            if !username.isSHA1() && !username.isEmpty && !isGroup {
                let label = UILabel(frame: CGRect(x: offset.x, y: offset.y, width: size, height: size))
                label.center = circle.center
                label.text = username.prefixString().capitalized
                label.font = UIFont.systemFont(ofSize: labelFontSize ?? (size * 0.44), weight: .semibold)
                label.textColor = .white
                label.textAlignment = .center
                addSubview(label)
            } else {
                let symbolSize = max((size * 0.40).rounded(), 6)
                let config = UIImage.SymbolConfiguration(pointSize: symbolSize, weight: .semibold)
                let symbolName = isGroup ? "person.2.fill" : "person.fill"
                if let image = UIImage(systemName: symbolName, withConfiguration: config) {
                    avatarImageView.image = image
                    avatarImageView.tintColor = .white
                    avatarImageView.contentMode = .center
                    addSubview(avatarImageView)
                }
            }
        }
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}

// MARK: - Avatar Helpers

/// Returns the avatar background color for a given display name.
func avatarBackgroundColor(for name: String) -> UIColor {
    let hex = name.toMD5HexString().prefixString()
    var idxValue: UInt64 = 0
    Scanner(string: hex).scanHexInt64(&idxValue)
    return avatarColors[Int(idxValue)]
}

struct MonogramHelper {
    static func initial(from text: String?) -> String {
        guard let text = text, !text.isEmpty else { return "" }
        return String(text.prefix(1)).uppercased()
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

    init(profileService: ProfilesService,
         size: Constants.AvatarSize,
         avatar avatarStream: Observable<Data?>,
         displayName nameStream: Observable<String?>,
         registeredName registeredStream: Observable<String?>,
         isGroup: Bool) {
        self.size = size
        self.profileService = profileService
        self.subscribeAvatar(observable: avatarStream)
        self.subscribeProfileName(observable: nameStream)
        self.subscribeRegisteredName(observable: registeredStream)
        self.isGroup = isGroup
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

    private func subscribeRegisteredName(observable: Observable<String?>) {
        observable
            .compactMap { $0 }
            .distinctUntilChanged()
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] name in
                self?.registeredName = name
            })
            .disposed(by: disposeBag)
    }

    func subscribeGroupParticipants(swarmInfo: SwarmInfoProtocol) {
        swarmInfo.avatarData.asObservable()
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] data in
                self?.hasCustomAvatar = data != nil
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
        let active = participants.filter { [.admin, .member, .invited].contains($0.role) }
        let maxAvatars = active.count <= 3 ? active.count : 2

        let admin = active.first { $0.role == .admin }
        let others = active.filter { $0 != admin }
        let sortedOthers = others.sorted { avatarPriority($0) > avatarPriority($1) }

        var visible: [ParticipantInfo] = []
        if let admin = admin {
            visible.append(admin)
        }
        visible.append(contentsOf: sortedOthers.prefix(maxAvatars - visible.count))

        let newOverflow = max(active.count - visible.count, 0)
        let visibleIds = visible.map { $0.jamiId }
        let currentIds = displayParticipants.map { $0.jamiId }
        let isFirstUpdate = !hasReceivedParticipants && !participants.isEmpty
        hasReceivedParticipants = hasReceivedParticipants || !participants.isEmpty
        guard visibleIds != currentIds || newOverflow != overflowCount || isFirstUpdate else { return }
        self.displayParticipants = visible
        self.overflowCount = newOverflow
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
        let totalSize = size.points
        let participants = displayParticipants
        let count = participants.count
        let overflow = overflowCount

        guard !participants.isEmpty else {
            groupAvatarSnapshot = renderEmptyGroupIcon(totalSize: totalSize)
            return
        }

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: totalSize, height: totalSize))
        groupAvatarSnapshot = renderer.image { ctx in
            let gc = ctx.cgContext
            let bounds = CGRect(x: 0, y: 0, width: totalSize, height: totalSize)
            let center = CGPoint(x: totalSize / 2, y: totalSize / 2)

            gc.saveGState()
            UIBezierPath(ovalIn: bounds).addClip()

            if count == 1 && overflow == 0 {
                drawParticipantCircle(in: gc, participant: participants[0],
                                      center: center, diameter: totalSize,
                                      shadowRadius: 0, shadowY: 0)
            } else {
                UIColor.systemGray6.setFill()
                UIBezierPath(ovalIn: bounds).fill()

                let hasThird = count > 2 || overflow > 0
                let adminSize = totalSize * (hasThird ? 0.46 : 0.52)
                let otherSize = totalSize * (hasThird ? 0.30 : 0.34)
                let shadowRadius = totalSize * 0.03
                let shadowY = totalSize * 0.015

                let offsets: [(x: CGFloat, y: CGFloat)] = hasThird
                    ? [(totalSize * -0.14, totalSize * -0.16),
                       (totalSize * 0.22, totalSize * 0.00),
                       (totalSize * -0.04, totalSize * 0.24)]
                    : [(totalSize * -0.14, totalSize * -0.14),
                       (totalSize * 0.18, totalSize * 0.18)]

                if hasThird {
                    let pos = CGPoint(x: center.x + offsets[2].x, y: center.y + offsets[2].y)
                    if overflow > 0 {
                        drawOverflowBadge(in: gc, center: pos, size: otherSize,
                                          count: overflow, shadowRadius: shadowRadius, shadowY: shadowY)
                    } else if count > 2 {
                        drawParticipantCircle(in: gc, participant: participants[2],
                                              center: pos, diameter: otherSize,
                                              shadowRadius: shadowRadius, shadowY: shadowY)
                    }
                }

                if count > 1 {
                    let pos = CGPoint(x: center.x + offsets[1].x, y: center.y + offsets[1].y)
                    drawParticipantCircle(in: gc, participant: participants[1],
                                          center: pos, diameter: otherSize,
                                          shadowRadius: shadowRadius, shadowY: shadowY)
                }

                let pos0 = CGPoint(x: center.x + offsets[0].x, y: center.y + offsets[0].y)
                drawParticipantCircle(in: gc, participant: participants[0],
                                      center: pos0, diameter: adminSize,
                                      shadowRadius: shadowRadius, shadowY: shadowY)
            }

            gc.restoreGState()
        }
    }

    private func drawParticipantCircle(in gc: CGContext, participant: ParticipantInfo,
                                       center: CGPoint, diameter: CGFloat,
                                       shadowRadius: CGFloat, shadowY: CGFloat) {
        let rect = CGRect(x: center.x - diameter / 2, y: center.y - diameter / 2,
                          width: diameter, height: diameter)
        let path = UIBezierPath(ovalIn: rect)

        gc.saveGState()
        if shadowRadius > 0 {
            gc.setShadow(offset: CGSize(width: 0, height: shadowY), blur: shadowRadius,
                         color: UIColor.black.withAlphaComponent(0.18).cgColor)
        }

        if let avatarImage = participant.provider.avatar {
            UIColor.white.setFill()
            path.fill()
            gc.setShadow(offset: .zero, blur: 0)
            gc.saveGState()
            path.addClip()
            avatarImage.draw(in: rect)
            gc.restoreGState()
        } else {
            let name = participant.finalName.value
            let bgColor = avatarBackgroundColor(for: name)

            bgColor.setFill()
            path.fill()
            gc.setShadow(offset: .zero, blur: 0)

            if let borderColor = bgColor.darker(by: 1) {
                borderColor.setStroke()
                path.lineWidth = 1
                path.stroke()
            }

            if !name.isSHA1() && !name.isEmpty {
                let fontSize = min(max((diameter * 0.44).rounded(), 8), 50)
                let letter = MonogramHelper.initial(from: name)
                let font = UIFont.systemFont(ofSize: fontSize, weight: .semibold)
                let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.white]
                let textSize = letter.size(withAttributes: attrs)
                letter.draw(at: CGPoint(x: center.x - textSize.width / 2,
                                        y: center.y - textSize.height / 2),
                            withAttributes: attrs)
            } else {
                let iconSize = max((diameter * 0.40).rounded(), 6)
                let config = UIImage.SymbolConfiguration(pointSize: iconSize, weight: .semibold)
                if let icon = UIImage(systemName: "person.fill", withConfiguration: config)?
                    .withTintColor(.white, renderingMode: .alwaysOriginal) {
                    icon.draw(at: CGPoint(x: center.x - icon.size.width / 2,
                                          y: center.y - icon.size.height / 2))
                }
            }
        }
        gc.restoreGState()
    }

    private func drawOverflowBadge(in gc: CGContext, center: CGPoint, size: CGFloat,
                                   count: Int, shadowRadius: CGFloat, shadowY: CGFloat) {
        let rect = CGRect(x: center.x - size / 2, y: center.y - size / 2, width: size, height: size)
        let path = UIBezierPath(ovalIn: rect)

        gc.saveGState()
        gc.setShadow(offset: CGSize(width: 0, height: shadowY), blur: shadowRadius,
                     color: UIColor.black.withAlphaComponent(0.18).cgColor)
        UIColor.systemGray3.setFill()
        path.fill()
        gc.setShadow(offset: .zero, blur: 0)

        let text = "+\(count)"
        let fontSize = size * 0.44
        let font = UIFont.systemFont(ofSize: fontSize, weight: .semibold)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.white]
        let textSize = text.size(withAttributes: attrs)
        text.draw(at: CGPoint(x: center.x - textSize.width / 2,
                              y: center.y - textSize.height / 2),
                  withAttributes: attrs)
        gc.restoreGState()
    }

    private func renderEmptyGroupIcon(totalSize: CGFloat) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: totalSize, height: totalSize))
        return renderer.image { _ in
            let bounds = CGRect(x: 0, y: 0, width: totalSize, height: totalSize)
            let center = CGPoint(x: totalSize / 2, y: totalSize / 2)
            let path = UIBezierPath(ovalIn: bounds)

            avatarColors[0].setFill()
            path.fill()
            if let borderColor = avatarColors[0].darker(by: 1) {
                borderColor.setStroke()
                path.lineWidth = 1
                path.stroke()
            }

            let iconSize = max((totalSize * 0.40).rounded(), 6)
            let config = UIImage.SymbolConfiguration(pointSize: iconSize, weight: .semibold)
            if let icon = UIImage(systemName: "person.2.fill", withConfiguration: config)?
                .withTintColor(.white, renderingMode: .alwaysOriginal) {
                icon.draw(at: CGPoint(x: center.x - icon.size.width / 2,
                                      y: center.y - icon.size.height / 2))
            }
        }
    }

    private func avatarPriority(_ participant: ParticipantInfo) -> Int {
        if participant.avatarData.value != nil { return 2 }
        let name = participant.finalName.value
        if !name.isSHA1() && !name.isEmpty { return 1 }
        return 0
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
                .interpolation(.none)
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
                .stroke(borderColor, lineWidth: 1)

            if !displayText.isSHA1() && !displayText.isEmpty && !source.isGroup {
                Text(MonogramHelper.initial(from: displayText))
                    .font(.system(size: monogramFontSize, weight: .semibold))
                    .foregroundColor(.white)
            } else {
                let iconSize = max((effectiveSize * 0.40).rounded(), 6)
                Image(systemName: source.isGroup ? "person.2.fill" : "person.fill")
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
    }

    private var resolvedDisplayText: String {
        if !source.profileName.isEmpty { return source.profileName }
        if !source.registeredName.isEmpty { return source.registeredName }
        return source.jamiId
    }

    private var monogramFontSize: CGFloat {
        min(max((effectiveSize * 0.44).rounded(), 8), 50)
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
