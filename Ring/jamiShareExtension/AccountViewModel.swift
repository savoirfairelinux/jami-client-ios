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
            guard let data = Data(base64Encoded: avatarString) else {
                return
            }
            let processedImage = UIImage.resizeImage(from: data, targetSize: Constants.defaultAvatarSize)
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
