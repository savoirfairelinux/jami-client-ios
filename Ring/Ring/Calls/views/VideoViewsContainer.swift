//
//  VideoViewsContainer.swift
//  Ring
//
//  Created by kateryna on 2023-05-18.
//  Copyright © 2023 Savoir-faire Linux. All rights reserved.
//

import Foundation
import RxSwift

class IncomingVideoModel {
    let videoInput: VideoInput
    var participant: ConferenceParticipant?

    init(videoInput: VideoInput) {
        self.videoInput = videoInput
    }
}

class IncomingVideoView: UIImageView {
    var model: IncomingVideoModel!
    private var disposeBag = DisposeBag()

    init(model: IncomingVideoModel, frame: CGRect) {
        self.model = model
        super.init(frame: frame)
        self.contentMode = .scaleAspectFit
        self.backgroundColor = UIColor.darkGray
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}

class VideoViewsContainer: UIView {
    private var views: [String: IncomingVideoView] = [String: IncomingVideoView]()
    private var participants = [ConferenceParticipant]()

    func addVideoInput(videoInput: VideoInput, renderId: String) {
        let model = IncomingVideoModel(videoInput: videoInput)
        let view = IncomingVideoView(model: model, frame: self.bounds)
        self.addSubview(view)
        self.views[renderId] = view
        layoutParticipantsViews()
    }

    func addParticipants(participants: [ConferenceParticipant]) {
        self.participants = participants
        updateViews()
        layoutParticipantsViews()
    }

    func updateViews() {
        for view in views {
            let participant = self.participants.filter { participant in
                return participant.sinkId == view.key
            }.first
            view.value.model.participant = participant
        }
    }

    func removeVideoInput(renderId: String) {
        if let view = self.views[renderId] {
            view.removeFromSuperview()
            self.views.removeValue(forKey: renderId)
        }

    }

    func layoutParticipantsViews() {
        if self.views.count == 1 {
            self.views.first?.value.frame = self.bounds
            return
        }

        let maxRows = 3
        let maxColumns = 3
        let height = self.frame.height / CGFloat(self.views.count)
        var index: CGFloat = 0
        self.views.forEach { pair in
            pair.value.frame = CGRect(x: 0, y: index * height, width: self.frame.width, height: height)
            index += 1
        }
    }
}
