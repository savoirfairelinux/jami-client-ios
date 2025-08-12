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
            // use fallback avatars
            let scanner = Scanner(string: username.toMD5HexString().prefixString())
            var index: UInt64 = 0
            if scanner.scanHexInt64(&index) {
                let fbaBGColor = avatarColors[Int(index)]
                let circle = UIView(frame: CGRect(x: offset.x, y: offset.y, width: size, height: size))
                circle.center = CGPoint.init(x: size / 2, y: self.center.y)
                circle.layer.cornerRadius = size / 2
                circle.backgroundColor = fbaBGColor
                circle.clipsToBounds = true
                self.addSubview(circle)
                if !username.isSHA1() && !username.isEmpty {
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
                    // ringId only, so fallback fallback avatar
                    if let image = UIImage(systemName: "person.fill") {
                        (avatarImageView as UIImageView).image = image
                        avatarImageView.tintColor = UIColor.white
                        avatarImageView.contentMode = .center
                        self.addSubview(avatarImageView)
                    }
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
    let textSize: CGFloat

    private let profileService: ProfilesService
    private let disposeBag = DisposeBag()

    init(profileService: ProfilesService, size: CGFloat, textSize: CGFloat = 22) {
        self.size = size
        self.profileService = profileService
        self.textSize = textSize
    }

    func subscribeAvatar(observable: Observable<Data?>) {
        observable
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] data in
                guard let self = self, let data = data else { return }
                self.avatar = self.profileService.getAvatarFor(data, size: self.size * 2)
            })
            .disposed(by: disposeBag)
    }

    func subscribeProfileName(observable: Observable<String?>) {
        observable
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] name in
                guard let self = self, let name = name else { return }
                self.profileName = name
            })
            .disposed(by: disposeBag)
    }

    func subscribeProfileName(observable: Observable<String>) {
        observable
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] name in
                guard let self = self else { return }
                self.profileName = name
            })
            .disposed(by: disposeBag)
    }


    func subscribeRegisteredName(observable: Observable<String>) {
        observable
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] name in
                guard let self = self else { return }
                self.profileName = name
            })
            .disposed(by: disposeBag)
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
        // Choose display text: prefer profileName, fallback to registeredName
        let displayText: String = !source.profileName.isEmpty ? source.profileName : (!source.registeredName.isEmpty ? source.registeredName : "")

        // Derive a stable color index (fallback to 0 if parsing fails)
        let hex = displayText.toMD5HexString().prefixString()
        var idxValue: UInt64 = 0
        let colorIndex = Scanner(string: hex).scanHexInt64(&idxValue) ? Int(idxValue) : 0
        let bgColor = avatarColors[colorIndex]

        ZStack {
            Color(bgColor)

            if !displayText.isSHA1() && !displayText.isEmpty {
                Text(MonogramHelper.extractFirstGraphemeCluster(from: displayText))
                    .font(.system(size: source.textSize, weight: .semibold))
                    .foregroundColor(.white)
            } else {
                Image(systemName: source.isGroup ? "person.2.fill" : "person.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(source.size * 0.3)
                    .foregroundColor(.white)
            }
        }
    }
}
