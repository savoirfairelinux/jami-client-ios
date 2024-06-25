/*
 *  Copyright (C) 2021 Savoir-faire Linux Inc.
 *
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
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
import SwiftyBeaver

class VideoManager {
    let log = SwiftyBeaver.self
    private let callService: CallsService
    private let videoService: VideoService

    private let disposeBag = DisposeBag()

    init(with callService: CallsService,
         videoService: VideoService) {
        self.callService = callService
        self.videoService = videoService
        VideoAdapter.decodingDelegate = self
        subscribeCallsEvents()
    }

    private func subscribeCallsEvents() {
        callService.sharedResponseStream
            .filter { event in
                event.eventType == .callEnded
            }
            .subscribe { [weak self] _ in
                guard let self = self else { return }
                let calls = self.callService.calls.value
                guard calls.count <= 1 else { return }
                self.videoService.stopCapture(withDevice: "camera://")
                self.videoService.setCameraOrientation(orientation: UIDevice.current.orientation)
            } onError: { _ in
            }
            .disposed(by: disposeBag)
    }
}

extension VideoManager: DecodingAdapterDelegate {
    func decodingStarted(withSinkId sinkId: String,
                         withWidth width: Int,
                         withHeight height: Int) {
        var accountId = ""
        var codecId: String?
        let call = callService.call(callID: sinkId)
        if let call = call,
           let codec = callService.getVideoCodec(call: call) {
            codecId = codec
            accountId = call.accountId
            callService.callMediaUpdated(call: call)
        }
        videoService.decodingStarted(
            withsinkId: sinkId,
            withWidth: width,
            withHeight: height,
            withCodec: codecId,
            withaAccountId: accountId,
            call: call
        )
    }

    func decodingStopped(withSinkId sinkId: String) {
        videoService.decodingStopped(withsinkId: sinkId)
    }
}
