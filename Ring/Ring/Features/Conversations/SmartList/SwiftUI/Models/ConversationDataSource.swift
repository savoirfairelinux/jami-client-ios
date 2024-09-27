/*
 *  Copyright (C) 2024 Savoir-faire Linux Inc.
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
import SwiftUI
import RxSwift
import RxRelay

class ConversationDataSource: ObservableObject {
    @Published var conversationViewModels = [ConversationViewModel]()
    let conversationsService: ConversationsService
    let accountsService: AccountsService
    var disposeBag = DisposeBag()
    let injectionBag: InjectionBag

    var onNewConversationViewModelCreated: ((ConversationModel) -> Void)?

    init(with injectionBag: InjectionBag) {
        self.injectionBag = injectionBag
        self.conversationsService = injectionBag.conversationsService
        self.accountsService = injectionBag.accountService
        self.subscribeToConversations()
        self.subscribeToConversationRemovals()
    }

    private func subscribeToConversations() {
        self.conversationsService.conversations
            .share()
            .observe(on: ConcurrentDispatchQueueScheduler(qos: .background))
            .map { [weak self] conversations -> [ConversationViewModel] in
                guard let self = self else { return [] }

                return conversations.map { conversationModel in
                    if let existing = self.conversationViewModels.first(where: { $0.conversation == conversationModel }) {
                        return existing
                    } else {
                        let newViewModel = ConversationViewModel(with: self.injectionBag)
                        newViewModel.conversation = conversationModel
                        // Notify that a new conversation view model is created.
                        // So temporary conversation could be updated if needed.
                        self.onNewConversationViewModelCreated?(conversationModel)
                        return newViewModel
                    }
                }
            }
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] updatedViewModels in
                self?.conversationViewModels = updatedViewModels
            })
            .disposed(by: disposeBag)
    }

    private func subscribeToConversationRemovals() {
        self.conversationsService.sharedResponseStream
            .filter { event in
                event.eventType == .conversationRemoved && event.getEventInput(.accountId) == self.accountsService.currentAccount?.id
            }
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] event in
                guard let self = self,
                      let conversationId: String = event.getEventInput(.conversationId),
                      let accountId: String = event.getEventInput(.accountId),
                      let index = self.conversationViewModels.firstIndex(where: { $0.conversation.id == conversationId && $0.conversation.accountId == accountId }) else { return }

                self.conversationViewModels.remove(at: index)
            })
            .disposed(by: disposeBag)
    }
}
