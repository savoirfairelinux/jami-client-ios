/*
 * Copyright (C) 2025-2025 Savoir-faire Linux Inc.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA.
 */

import RxSwift

class ActiveCallsViewModel: ObservableObject, Stateable {
    @Published var callsByAccount: [String: [ActiveCallRowViewModel]] = [:]

    private let callService: CallsService
    private let profileService: ProfilesService
    private let accountsService: AccountsService
    private let conversationsSource: ConversationDataSource
    private let disposeBag = DisposeBag()

    private let stateSubject = PublishSubject<State>()
    lazy var state: Observable<State> = {
        return self.stateSubject.asObservable()
    }()

    init(injectionBag: InjectionBag, conversationsSource: ConversationDataSource) {
        self.callService = injectionBag.callService
        self.profileService = injectionBag.profileService
        self.accountsService = injectionBag.accountService
        self.conversationsSource = conversationsSource
        self.observeActiveCalls()
    }

    private func observeActiveCalls() {
        callService.activeCalls
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] trackersByAccount in
                self?.updateCallViewModels(from: trackersByAccount)
            })
            .disposed(by: disposeBag)
    }

    private func updateCallViewModels(from trackersByAccount: [String: AccountCallTracker]) {
        // Linked accounts sharing a swarm receive the same call in each
        // tracker. Dedup by remote identity; iterate the current account
        // first so the remaining row belongs to it.
        let currentId = accountsService.currentAccount?.id
        let orderedAccountIds: [String] = {
            let ids = Array(trackersByAccount.keys)
            if let currentId = currentId {
                return [currentId] + ids.filter { $0 != currentId }
            }
            return ids
        }()

        var seen = Set<RemoteCallIdentity>()
        var grouped: [String: [ActiveCallRowViewModel]] = [:]
        for accountId in orderedAccountIds {
            guard let tracker = trackersByAccount[accountId] else { continue }
            for call in tracker.incomingNotAcceptedNotIgnoredCalls() {
                if seen.contains(call.remoteIdentity) { continue }
                guard let conversation = findConversation(for: call),
                      let swarmInfo = conversation.swarmInfo else { continue }
                seen.insert(call.remoteIdentity)
                let row = ActiveCallRowViewModel(
                    call: call,
                    stateSubject: stateSubject,
                    callService: callService,
                    swarmInfo: swarmInfo,
                    profileService: self.profileService
                )
                grouped[accountId, default: []].append(row)
            }
        }
        callsByAccount = grouped
    }

    private func findConversation(for call: ActiveCall) -> ConversationViewModel? {
        return conversationsSource.conversationViewModels.first { $0.conversation?.id == call.conversationId }
    }
}

class ActiveCallRowViewModel: ObservableObject, Equatable {
    @Published var title = ""
    @Published var avatarData: Data?
    let call: ActiveCall
    private let stateSubject: PublishSubject<State>
    private let callService: CallsService
    let profileService: ProfilesService
    private let disposeBag = DisposeBag()
    let avatarProvider: AvatarProvider

    init(call: ActiveCall, stateSubject: PublishSubject<State>, callService: CallsService, swarmInfo: SwarmInfoProtocol, profileService: ProfilesService) {
        self.call = call
        self.profileService = profileService
        self.callService = callService
        self.stateSubject = stateSubject
        self.avatarProvider = AvatarProvider.from(swarmInfo: swarmInfo, profileService: profileService, size: Constants.AvatarSize.default55)

        self.subscribeToSwarmInfo(swarmInfo: swarmInfo)
    }

    private func subscribeToSwarmInfo(swarmInfo: SwarmInfoProtocol) {
        swarmInfo.finalTitle
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] title in
                self?.title = title
            })
            .disposed(by: disposeBag)
    }

    func acceptCall() {
        let uri = call.constructURI()
        stateSubject.onNext(ConversationState.startCall(contactRingId: uri, userName: ""))
    }

    func acceptAudioCall() {
        let uri = call.constructURI()
        stateSubject.onNext(ConversationState.startAudioCall(contactRingId: uri, userName: ""))
    }

    func rejectCall() {
        callService.ignoreCall(call: call)
    }

    static func == (lhs: ActiveCallRowViewModel, rhs: ActiveCallRowViewModel) -> Bool {
        return lhs.call.id == rhs.call.id &&
            lhs.title == rhs.title
    }
}
