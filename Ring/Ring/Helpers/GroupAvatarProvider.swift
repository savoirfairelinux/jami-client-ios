/*
 *  Copyright (C) 2026 - 2026 Savoir-faire Linux Inc.
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

class GroupAvatarProvider: ObservableObject {
    @Published var displayParticipants: [ParticipantInfo] = []
    @Published var overflowCount: Int = 0
    @Published var hasCustomAvatar: Bool = false

    let totalSize: CGFloat
    private let disposeBag = DisposeBag()

    init(swarmInfo: SwarmInfoProtocol, totalSize: CGFloat) {
        self.totalSize = totalSize

        swarmInfo.avatarData.asObservable()
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] data in
                self?.hasCustomAvatar = data != nil
            })
            .disposed(by: disposeBag)

        Observable.combineLatest(
            swarmInfo.participants.asObservable(),
            swarmInfo.participantsAvatars.asObservable()
        )
        .observe(on: MainScheduler.instance)
        .subscribe(onNext: { [weak self] (participants, _) in
            self?.updateDisplay(participants: participants)
        })
        .disposed(by: disposeBag)
    }

    private func updateDisplay(participants: [ParticipantInfo]) {
        let active = participants.filter { [.admin, .member, .invited].contains($0.role) }
        let maxAvatars = active.count <= 3 ? active.count : 2

        let admin = active.first { $0.role == .admin }
        let others = active.filter { $0 != admin }
        let sortedOthers = others.sorted { avatarPriority($0) > avatarPriority($1) }

        var visible: [ParticipantInfo] = []
        if let admin = admin {
            visible.append(admin)
        }
        visible.append(contentsOf: sortedOthers.prefix(maxAvatars - visible.count))

        self.displayParticipants = visible
        self.overflowCount = max(active.count - visible.count, 0)
    }

    private func avatarPriority(_ participant: ParticipantInfo) -> Int {
        if participant.avatarData.value != nil { return 2 }
        let name = participant.finalName.value
        if !name.isSHA1() && !name.isEmpty { return 1 }
        return 0
    }
}
