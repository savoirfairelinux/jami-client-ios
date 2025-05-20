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

import RxSwift

class ConversationViewModel: ObservableObject, Identifiable, Equatable {
    let id: String
    let accountId: String
    @Published var name: String
    @Published var avatar: String
    @Published var accountType: String

    private let adapterService: AdapterService
    private let disposeBag = DisposeBag()

    init(id: String, accountId: String, adapterService: AdapterService, initialName: String = "", initialAvatar: String = "", initialAccountType: String = "jamiid") {
        self.id = id
        self.accountId = accountId
        self.adapterService = adapterService
        self.name = initialName
        self.avatar = initialAvatar
        self.accountType = initialAccountType
        fetchConversationDetails()
    }

    static func == (lhs: ConversationViewModel, rhs: ConversationViewModel) -> Bool {
        lhs.id == rhs.id && lhs.accountId == rhs.accountId
    }

    private func fetchConversationDetails() {
        adapterService.getConversationInfo(accountId: accountId, conversationId: id)
            .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background)) 
            .observe(on: MainScheduler.instance)                               
            .subscribe(onSuccess: { [weak self] details in
                self?.name = details.name
                self?.avatar = details.avatar ?? ""
                self?.accountType = details.accountType
            })
            .disposed(by: disposeBag)
    }
}
