/*
 *  Copyright (C) 2025 - 2025 Savoir-faire Linux Inc.
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
import RxSwift
import RxRelay
import SwiftUI

class CallBannerViewModel: ObservableObject {
    @Published var isVisible = false
    @Published var activeCalls: [ActiveCall] = []

    private let callService: CallsService
    private let conversation: ConversationModel
    private let disposeBag = DisposeBag()
    private let state: PublishSubject<State>

    init(injectionBag: InjectionBag, conversation: ConversationModel, state: PublishSubject<State>) {
        self.callService = injectionBag.callService
        self.conversation = conversation
        self.state = state

        setupCallSubscription()
    }

    private func setupCallSubscription() {
        callService.activeCalls
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] accountCalls in
                guard let self = self,
                      let accountCalls = accountCalls[self.conversation.accountId],
                      !accountCalls
                        .notAnsweredCalls(for: self.conversation.id)
                        .filter({ !$0.isfromLocalDevice }).isEmpty else {
                    self?.isVisible = false
                    self?.activeCalls = []
                    return
                }
                let calls = accountCalls.notAnsweredCalls(for: self.conversation.id).filter { !$0.isfromLocalDevice }
                self.activeCalls = calls
                self.isVisible = true
            })
            .disposed(by: disposeBag)
    }

    func acceptVideoCall(for call: ActiveCall) {
        self.state.onNext(MessagePanelState.joinActiveCall(call: call, withVideo: true))
    }

    func acceptAudioCall(for call: ActiveCall) {
        self.state.onNext(MessagePanelState.joinActiveCall(call: call, withVideo: false))
    }
}
