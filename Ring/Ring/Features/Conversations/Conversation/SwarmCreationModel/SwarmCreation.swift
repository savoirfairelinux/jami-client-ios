/*
 *  Copyright (C) 2022 Savoir-faire Linux Inc.
 *
 *  Author: Binal Ahiya <binal.ahiya@savoirfairelinux.com>
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

class ParticipantRow: Identifiable, ObservableObject {
    @Published var id: String
    @Published var imageDataFinal: UIImage = UIImage()
    @Published var name: String = ""

    let disposeBag = DisposeBag()

    init(participantData: ParticipantInfo) {
        self.id = participantData.jamiId
        self.name = participantData.name.value
        participantData.name
            .observe(on: MainScheduler.instance)
            .startWith(participantData.name.value)
            .subscribe {[weak self] name in
                guard let self = self else { return }
                self.name = name
            } onError: { _ in

            }
            .disposed(by: self.disposeBag)

        participantData.avatar
            .observe(on: MainScheduler.instance)
            .startWith(participantData.avatar.value)
            .subscribe {[weak self] avatar in
                guard let self = self, let avatar = avatar else { return }
                self.imageDataFinal = avatar
            } onError: { _ in

            }
            .disposed(by: self.disposeBag)

    }
    func match(string: String) -> Bool {
        return name.lowercased().contains(string.lowercased()) || id.lowercased().contains(string.lowercased())
    }
}
