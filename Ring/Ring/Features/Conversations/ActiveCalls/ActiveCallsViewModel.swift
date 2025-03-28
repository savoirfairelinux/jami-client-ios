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

class ActiveCallsViewModel: ObservableObject, Stateable {
    @Published var callsByAccount: [String: [ActiveCallRowViewModel]] = [:]

    private let callService: CallsService
    private let accountsService: AccountsService
    private let conversationsSource: ConversationDataSource
    private let disposeBag = DisposeBag()

    private let stateSubject = PublishSubject<State>()
    lazy var state: Observable<State> = {
        return self.stateSubject.asObservable()
    }()

    init(injectionBag: InjectionBag, conversationsSource: ConversationDataSource) {
        self.callService = injectionBag.callService
        self.accountsService = injectionBag.accountService
        self.conversationsSource = conversationsSource
        self.subscribeToActiveCalls()
    }

    private func subscribeToActiveCalls() {
        callService.activeCalls
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] accountCalls in
                guard let self = self else { return }
                self.handleActiveCalls(accountCalls)
            })
            .disposed(by: disposeBag)
    }

    private func handleActiveCalls(_ accountCalls: [String: AccountCalls]) {
        for (accountId, accountCalls) in accountCalls {
            let calls = getNonLocalCalls(from: accountCalls)
            handleCallsForAccount(accountId: accountId, calls: calls)
        }
    }

    private func getNonLocalCalls(from accountCalls: AccountCalls) -> [ActiveCall] {
        let conversationIds = accountCalls.allConversationIds
        return conversationIds.flatMap { conversationId in
            let answeredCalls = accountCalls.answeredCalls(for: conversationId)
            return accountCalls.notIgnoredCalls(for: conversationId)
                .filter { !$0.isfromLocalDevice && !answeredCalls.contains($0) }
        }
    }

    private func handleCallsForAccount(accountId: String, calls: [ActiveCall]) {
        var viewModels = [ActiveCallRowViewModel]()
        for call in calls {
            guard let conversation = findConversation(for: call),
                  let swarmInfo = conversation.swarmInfo else { continue }
            let viewModel = ActiveCallRowViewModel(
                call: call,
                stateSubject: stateSubject,
                callService: callService,
                swarmInfo: swarmInfo
            )
            viewModels.append(viewModel)
        }
        callsByAccount[accountId] = viewModels
    }

    private func findConversation(for call: ActiveCall) -> ConversationViewModel? {
        return conversationsSource.conversationViewModels.first { $0.conversation?.id == call.conversationId }
    }
}

class ActiveCallRowViewModel: ObservableObject, Equatable {
    @Published var title = ""
    @Published var avatar: UIImage?
    let call: ActiveCall
    private let stateSubject: PublishSubject<State>
    private let callService: CallsService
    private let disposeBag = DisposeBag()

    init(call: ActiveCall, stateSubject: PublishSubject<State>, callService: CallsService, swarmInfo: SwarmInfoProtocol) {
        self.call = call
        self.callService = callService
        self.stateSubject = stateSubject
        self.subscribeToSwarmInfo(swarmInfo: swarmInfo)
    }

    private func subscribeToSwarmInfo(swarmInfo: SwarmInfoProtocol) {
        swarmInfo.finalTitle
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] title in
                self?.title = title
            })
            .disposed(by: disposeBag)

        swarmInfo.finalAvatar
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] avatar in
                self?.avatar = avatar
            })
            .disposed(by: disposeBag)
    }

    func acceptCall() {
        let uri = constructCallURI()
        stateSubject.onNext(ConversationState.startCall(contactRingId: uri, userName: ""))
    }

    func acceptAudioCall() {
        let uri = constructCallURI()
        stateSubject.onNext(ConversationState.startAudioCall(contactRingId: uri, userName: ""))
    }

    func rejectCall() {
        callService.ignoreCall(call: call)
    }

    private func constructCallURI() -> String {
        return "rdv:" + call.conversationId + "/" + call.uri + "/" + call.device + "/" + call.id
    }

    static func == (lhs: ActiveCallRowViewModel, rhs: ActiveCallRowViewModel) -> Bool {
        return lhs.call.id == rhs.call.id &&
            lhs.title == rhs.title &&
            lhs.avatar == rhs.avatar
    }
}
