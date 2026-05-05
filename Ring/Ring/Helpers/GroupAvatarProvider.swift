/*
 *  Copyright (C) 2025 Savoir-faire Linux Inc.
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
    private let maxVisible: Int
    private let disposeBag = DisposeBag()

    init(swarmInfo: SwarmInfoProtocol, totalSize: CGFloat) {
        self.totalSize = totalSize
        self.maxVisible = totalSize >= 80 ? 3 : 2

        swarmInfo.avatarData.asObservable()
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] data in
                self?.hasCustomAvatar = data != nil
            })
            .disposed(by: disposeBag)

        swarmInfo.participants.asObservable()
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] participants in
                guard let self = self else { return }
                let active = participants.filter { [.admin, .member, .invited].contains($0.role) }
                let visible = Array(active.prefix(self.maxVisible))
                self.displayParticipants = visible
                self.overflowCount = max(active.count - visible.count, 0)
            })
            .disposed(by: disposeBag)
    }
}
