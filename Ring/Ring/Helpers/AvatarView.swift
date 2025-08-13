/*
 *  Copyright (C) 2016-2019 Savoir-faire Linux Inc.
 *
 *  Author: Andreas Traczyk <andreas.traczyk@savoirfairelinux.com>
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

import Foundation
import UIKit
import SwiftUI
import RxSwift
import RxRelay

 class AvatarView: UIView {
    init(image: UIImage,
         size: CGFloat = 32.0) {

        let frame = CGRect(x: 0, y: 0, width: size, height: size)

        super.init(frame: frame)
        self.frame = CGRect(x: 0, y: 0, width: size, height: size)

        let avatarImageView = UIImageView(frame: CGRect(x: 0, y: 0, width: size, height: size))
        (avatarImageView as UIImageView).image = image
        avatarImageView.layer.masksToBounds = false
        avatarImageView.layer.cornerRadius = avatarImageView.frame.height / 2
        avatarImageView.clipsToBounds = true
        avatarImageView.contentMode = .scaleAspectFill
        self.addSubview(avatarImageView)
    }

     init(profileImageData: Data?,
          username: String,
          isGroup: Bool,
          size: CGFloat = 32.0,
          offset: CGPoint = CGPoint(x: 0.0, y: 0.0),
          labelFontSize: CGFloat? = nil) {

         let frame = CGRect(x: 0, y: 0, width: size, height: size)

         super.init(frame: frame)
         self.frame = CGRect(x: 0, y: 0, width: size, height: size)

         let avatarImageView = UIImageView(frame: CGRect(x: 0, y: 0, width: size, height: size))
         if let imageData = profileImageData, !imageData.isEmpty {
             if let image = UIImage(data: imageData) {
                 (avatarImageView as UIImageView).image = image
                 avatarImageView.layer.masksToBounds = false
                 avatarImageView.layer.cornerRadius = avatarImageView.frame.height / 2
                 avatarImageView.clipsToBounds = true
                 avatarImageView.contentMode = .scaleAspectFill
                 self.addSubview(avatarImageView)
             }
         } else {
             let hex = username.toMD5HexString().prefixString()
             var idxValue: UInt64 = 0
             let colorIndex = Scanner(string: hex).scanHexInt64(&idxValue) ? Int(idxValue) : 0
             let fbaBGColor = avatarColors[colorIndex]
             let circle = UIView(frame: CGRect(x: offset.x, y: offset.y, width: size, height: size))
             circle.center = CGPoint.init(x: size / 2, y: self.center.y)
             circle.layer.cornerRadius = size / 2
             circle.backgroundColor = fbaBGColor
             circle.clipsToBounds = true
             self.addSubview(circle)
             if !username.isSHA1() && !username.isEmpty && !isGroup {
                 // use g-style fallback avatar
                 let initialLabel: UILabel = UILabel.init(frame: CGRect.init(x: offset.x, y: offset.y, width: size, height: size))
                 initialLabel.center = circle.center
                 initialLabel.text = username.prefixString().capitalized
                 let fontSize = (labelFontSize != nil) ? labelFontSize! : (size * 0.44)
                 initialLabel.font = UIFont.systemFont(ofSize: fontSize, weight: .semibold)
                 initialLabel.textColor = UIColor.white
                 initialLabel.textAlignment = .center
                 self.addSubview(initialLabel)
            } else {
                // ringId only or group
                let symbolSize = max((size * 0.40).rounded(), 6)
                let configuration = UIImage.SymbolConfiguration(pointSize: symbolSize, weight: .semibold)
                if let image = (isGroup ? UIImage(systemName: "person.2.fill", withConfiguration: configuration)
                                        : UIImage(systemName: "person.fill", withConfiguration: configuration)) {
                    (avatarImageView as UIImageView).image = image
                    avatarImageView.tintColor = UIColor.white
                    avatarImageView.contentMode = .center
                    self.addSubview(avatarImageView)
                }
            }
         }
     }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
 }

// MARK: - Monogram Helper
struct MonogramHelper {
    static func extractFirstGraphemeCluster(from text: String?) -> String {
        guard let text = text, !text.isEmpty else { return "" }

        let firstGrapheme = String(text.prefix(1))
        return firstGrapheme.uppercased()
    }
}

class AvatarProvider: ObservableObject {
    @Published var avatar: UIImage?
    @Published var profileName: String = ""
    @Published var registeredName: String = ""
    @Published var isGroup: Bool = false
    let size: CGFloat
    

    private let profileService: ProfilesService
    private let disposeBag = DisposeBag()

    init(profileService: ProfilesService,
         size: CGFloat,
         avatar avatarStream: Observable<Data?>,
         displayName nameStream: Observable<String>,
         isGroup: Bool) {
        self.size = size
        self.profileService = profileService
        self.subscribeAvatar(observable: avatarStream)
        self.subscribeProfileName(observable: nameStream)
        self.isGroup = isGroup
    }

    private func subscribeAvatar(observable: Observable<Data?>) {
        observable
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] data in
                guard let self = self, let data = data else { return }
                let decodeSize = max(self.size * 2, AvatarSizing.primarySize * 2)
                self.avatar = self.profileService.getAvatarFor(data, size: decodeSize)
            })
            .disposed(by: disposeBag)
    }

    private func subscribeProfileName(observable: Observable<String?>) {
        observable
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] name in
                guard let self = self, let name = name else { return }
                self.profileName = name
            })
            .disposed(by: disposeBag)
    }

    private func subscribeProfileName(observable: Observable<String>) {
        observable
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] name in
                guard let self = self else { return }
                self.profileName = name
            })
            .disposed(by: disposeBag)
    }


    private func subscribeRegisteredName(observable: Observable<String>) {
        observable
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] name in
                guard let self = self else { return }
                self.profileName = name
            })
            .disposed(by: disposeBag)
    }
}

// MARK: - Builders for common contexts
extension AvatarProvider {
    static func from(participant: ParticipantInfo, size: CGFloat) -> AvatarProvider {
        return AvatarProvider(
            profileService: participant.profileService,
            size: size,
            avatar: participant.avatarData.asObservable(),
            displayName: participant.finalName.asObservable(),
            isGroup: false
        )
    }

    static func from(participantRow: ParticipantRow, size: CGFloat) -> AvatarProvider {
        return AvatarProvider(
            profileService: participantRow.profileService,
            size: size,
            avatar: participantRow.avatarData.asObservable(),
            displayName: participantRow.finalName.asObservable(),
            isGroup: false
        )
    }

    static func from(swarmInfo: SwarmInfoProtocol, profileService: ProfilesService, size: CGFloat) -> AvatarProvider {
        return AvatarProvider(
            profileService: profileService,
            size: size,
            avatar: swarmInfo.finalAvatarData,
            displayName: swarmInfo.finalTitle.asObservable(),
            isGroup: !(swarmInfo.conversation?.isDialog() ?? false)
        )
    }

    static func from(activeCallVM: ActiveCallRowViewModel, size: CGFloat) -> AvatarProvider {
        return AvatarProvider(
            profileService: activeCallVM.profileService,
            size: size,
            avatar: Observable.just(activeCallVM.avatarData),
            displayName: Observable.just(activeCallVM.title),
            isGroup: activeCallVM.isGroup
        )
    }
}

struct AvatarSwiftUIView: View {
   @ObservedObject var source: AvatarProvider

    var body: some View {
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
        .frame(width: source.size, height: source.size)
        .clipShape(Circle())
    }

    @ViewBuilder
    private var monogramView: some View {
        let displayText: String = !source.profileName.isEmpty ? source.profileName : (!source.registeredName.isEmpty ? source.registeredName : "")

        let hex = displayText.toMD5HexString().prefixString()
        var idxValue: UInt64 = 0
        let colorIndex = Scanner(string: hex).scanHexInt64(&idxValue) ? Int(idxValue) : 0
        let bgColor = avatarColors[colorIndex]

        ZStack {
            Color(bgColor)
            let borderUIColor = bgColor.darker(by: 1) ?? bgColor
            let borderLineWidth = min(max(source.size * 0.04, 1), 1)
            Circle()
                .stroke(Color(borderUIColor), lineWidth: borderLineWidth)

            if !displayText.isSHA1() && !displayText.isEmpty && !source.isGroup {
                let computedFontSize = monogramFontSize(for: source.size)
                Text(MonogramHelper.extractFirstGraphemeCluster(from: displayText))
                    .font(.system(size: computedFontSize, weight: .semibold))
                    .foregroundColor(.white)
            } else {
                // Slightly smaller icon than letter to create inner padding in the circle
                let iconFontSize = max((source.size * 0.40).rounded(), 6)
                Image(systemName: source.isGroup ? "person.2.fill" : "person.fill")
                    .font(.system(size: iconFontSize, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
    }

    // Keep a consistent letter-to-circle ratio across sizes using a single multiplier.
    // Using ~0.44x maintains similar proportions across 30, 40, 55, and 150 sizes.
    private func monogramFontSize(for avatarSize: CGFloat) -> CGFloat {
        let factor: CGFloat = 0.44
        let raw = avatarSize * factor
        return min(max(raw.rounded(), 8), 50)
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

    func provider(for jamiId: String, size: CGFloat) -> AvatarProvider {
        let key = "\(jamiId)|\(Int(size))"
        if let existing = cache[key] { return existing }
        let provider = AvatarProvider(
            profileService: profileService,
            size: size,
            avatar: relayProvider.avatarRelay(for: jamiId).asObservable(),
            displayName: relayProvider.nameRelay(for: jamiId).asObservable(),
            isGroup:false
        )
        cache[key] = provider
        return provider
    }

    static func provider(profileService: ProfilesService,
                         size: CGFloat,
                         avatar: Observable<Data?>,
                         displayName: Observable<String>,
                         isGroup: Bool = false) -> AvatarProvider {
        return AvatarProvider(
            profileService: profileService,
            size: size,
            avatar: avatar,
            displayName: displayName,
            isGroup: isGroup
        )
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
