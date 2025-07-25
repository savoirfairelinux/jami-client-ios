/*
 *  Copyright (C) 2025-2025 Savoir-faire Linux Inc.
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
import ImageIO
import SwiftUI
import RxSwift

struct AccountDetails {
    let accountId: String
    let accountName: String
    let accountAvatarType: AvatarType
    let accountAvatar: String
}

enum AvatarType: String {
    case jamiid
    case single
    case group
}

class AccountViewModel: ObservableObject, Identifiable, Equatable {
    let id: String
    @Published var name: String {
        didSet {
            bgColor = Color(backgroundColor(for: name))
        }
    }
    @Published var avatarType: AvatarType
    @Published var avatar: String {
        didSet {
            updateProcessedAvatar()
        }
    }
    @Published var processedAvatar: UIImage?
    @Published var bgColor = Color(UIColor(hexString: "808080")!)

    private let adapterService: AdapterService
    private let disposeBag = DisposeBag()

    init(id: String, adapterService: AdapterService, initialName: String = "", initialAvatar: String = "", initialAvatarType: AvatarType = .jamiid) {
        self.id = id
        self.adapterService = adapterService
        self.name = initialName
        self.avatar = initialAvatar
        self.avatarType = initialAvatarType
        updateProcessedAvatar()
        self.fetchAccountDetails()
    }

    static func == (lhs: AccountViewModel, rhs: AccountViewModel) -> Bool {
        lhs.id == rhs.id
    }

    private func updateProcessedAvatar() {
        guard !avatar.isEmpty else {
            DispatchQueue.main.async { [weak self] in
                self?.processedAvatar = nil
            }
            return
        }

        let avatarString = avatar
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let processedImage = ImageUtils().imageFromBase64(avatarString, targetSize: CGSize(width: 45, height: 45))

            DispatchQueue.main.async { [weak self] in
                guard let self = self, self.avatar == avatarString else { return }
                self.processedAvatar = processedImage
            }
        }
    }

    private func fetchAccountDetails() {
        adapterService.resolveLocalAccountName(from: id)
            .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] nameInfo in
                self?.name = nameInfo.value
                self?.avatarType = nameInfo.avatarType
            })
            .disposed(by: disposeBag)

        adapterService.resolveLocalAccountAvatar(accountId: id)
            .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] avatarString in
                self?.avatar = avatarString
            })
            .disposed(by: disposeBag)
    }
}

class ImageUtils {

    func imageFromBase64(_ base64: String, targetSize: CGSize) -> UIImage? {
        guard let data = Data(base64Encoded: base64) else { return nil }

        return downsampleImage(from: data, to: targetSize)
    }

    private func downsampleImage(from imageData: Data, to targetSize: CGSize) -> UIImage? {
        let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let imageSource = CGImageSourceCreateWithData(imageData as CFData, imageSourceOptions) else {
            return UIImage(data: imageData)
        }

        let maxDimensionInPixels = max(targetSize.width, targetSize.height) * UIScreen.main.scale

        let downsampleOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimensionInPixels
        ] as CFDictionary

        guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions) else {
            guard let fullImage = UIImage(data: imageData) else { return nil }
            return resizeImage(fullImage, to: targetSize)
        }

        return UIImage(cgImage: downsampledImage)
    }

    private func resizeImage(_ image: UIImage, to targetSize: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
