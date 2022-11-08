//
//  SwarmCreation.swift
//  Ring
//
//  Created by Binal Ahiya on 2022-11-11.
//  Copyright © 2022 Savoir-faire Linux. All rights reserved.
//

import Foundation
import SwiftUI
import RxSwift

class ParticipantRow: Identifiable, ObservableObject {
    @Published var id: String
    @Published var imageDataFinal: UIImage = UIImage()
    @Published var name: String = ""

    let disposeBag = DisposeBag()

    init(participantData: ParticipantData) {
        self.id = participantData.jamiId
        participantData.name
            .startWith(participantData.name.value)
            .subscribe {[weak self] name in
                guard let self = self else { return }
                self.name = name
            } onError: { _ in

            }
            .disposed(by: self.disposeBag)

        participantData.avatar
            .startWith(participantData.avatar.value)
            .subscribe {[weak self] avatar in
                guard let self = self, let avatar = avatar else { return }
                self.imageDataFinal = avatar
            } onError: { _ in

            }
            .disposed(by: self.disposeBag)

    }
}
