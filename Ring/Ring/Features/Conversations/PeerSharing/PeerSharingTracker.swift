/*
 *  Copyright (C) 2026 Savoir-faire Linux Inc.
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

class PeerSharingTracker: ObservableObject {
    @Published private(set) var hasPeerSharing = false

    private let peerSharingService: PeerSharingService
    private var accountId: String?
    private var peerId: String?
    private var disposeBag = DisposeBag()

    init(peerSharingService: PeerSharingService) {
        self.peerSharingService = peerSharingService
    }

    func track(_ conversation: ConversationModel, isBlocked: Bool) {
        disposeBag = DisposeBag()
        let peerId = conversation.isCoredialog() && !isBlocked
            ? conversation.getParticipants().first?.jamiId
            : nil
        let accountId = conversation.accountId
        onMain { [weak self] in
            self?.accountId = accountId
            self?.peerId = peerId
            self?.hasPeerSharing = false
        }
        guard let peerId = peerId else { return }

        Observable.merge(peerSharingService.observePeerServices(accountId: accountId, peerId: peerId),
                         peerSharingService.queryPeerServices(accountId: accountId, peerId: peerId))
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] result in
                self?.apply(result, accountId: accountId, peerId: peerId)
            })
            .disposed(by: disposeBag)
    }

    func makePeerSharingViewModel() -> PeerSharingViewModel? {
        guard let accountId = accountId, let peerId = peerId else { return nil }
        return PeerSharingViewModel(accountId: accountId,
                                    peerId: peerId,
                                    peerSharingService: peerSharingService)
    }

    private func apply(_ result: PeerServicesResult, accountId: String, peerId: String) {
        guard self.accountId == accountId, self.peerId == peerId else { return }
        hasPeerSharing = result.hasExposedServices
    }
}
