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

class ConversationViewModel: ObservableObject, Identifiable, Equatable {
    let id: String
    let accountId: String
    @Published var name: String {
        didSet {
            bgColor = Color(backgroundColor(for: name))
        }
    }
    @Published var avatar: String {
        didSet {
            updateProcessedAvatar()
        }
    }
    @Published var avatarType: AvatarType
    @Published var processedAvatar: UIImage?
    @Published var bgColor = Color(UIColor(hexString: "808080")!)

    private let adapterService: AdapterService
    private let disposeBag = DisposeBag()
    private var hasLoadedDetails = false

    init(id: String, accountId: String, adapterService: AdapterService, initialName: String = "", initialAvatar: String = "", initialAvatarType: AvatarType = .jamiid) {
        self.id = id
        self.accountId = accountId
        self.adapterService = adapterService
        self.name = initialName
        self.avatar = initialAvatar
        self.avatarType = initialAvatarType
        updateProcessedAvatar()
    }

    static func == (lhs: ConversationViewModel, rhs: ConversationViewModel) -> Bool {
        lhs.id == rhs.id && lhs.accountId == rhs.accountId
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

    func loadDetailsIfNeeded() {
        guard !hasLoadedDetails else { return }
        hasLoadedDetails = true
        fetchConversationDetails()
    }

    private func fetchConversationDetails() {
        adapterService.getConversationName(accountId: accountId, conversationId: id)
            .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] nameInfo in
                self?.name = nameInfo.name
                self?.avatarType = nameInfo.avatarType
            })
            .disposed(by: disposeBag)

        adapterService.getConversationAvatar(accountId: accountId, conversationId: id)
            .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] avatarString in
                self?.avatar = avatarString ?? ""
            })
            .disposed(by: disposeBag)
    }
}
