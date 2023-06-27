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
    let displayLayer = AVSampleBufferDisplayLayer()
    @Published var name = ""
    let disposeBag = DisposeBag()

    init(videoInput: VideoInput) {
        self.videoInput = videoInput
        self.id = videoInput.renderId
        displayLayer.videoGravity = .resizeAspectFill
        self.videoInput.frame
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { image in
                guard let image = image else { return }
                DispatchQueue.main.async {
                    if let container = self.displayLayer.superlayer?.delegate as? UIView,
                       container.bounds != self.displayLayer.frame {
                        CATransaction.begin()
                        CATransaction.setDisableActions(true)
                        self.displayLayer.frame = container.bounds
                        CATransaction.commit()
                    }
                    self.displayLayer.enqueue(image)
                }
            })
            .disposed(by: self.disposeBag)
    }
}
