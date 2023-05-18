//
//  ParticipantViewModel.swift
//  Ring
//
//  Created by kateryna on 2023-06-01.
//  Copyright © 2023 Savoir-faire Linux. All rights reserved.
//

import Foundation
import RxSwift

class ParticipantViewModel: Identifiable, ObservableObject {
    let videoInput: VideoInput
    var info: ConferenceParticipant?
    let id: String
    @Published var image: CMSampleBuffer?
    @Published var name = ""
    let disposeBag = DisposeBag()

    init(videoInput: VideoInput) {
        self.videoInput = videoInput
        self.id = videoInput.renderId
        self.videoInput.frame
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { image in
                DispatchQueue.main.async {
                    self.image = image
                }
            })
            .disposed(by: self.disposeBag)
    }
}
