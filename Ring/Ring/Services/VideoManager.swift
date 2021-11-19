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
    private let callsProvider: CallsProviderDelegate
    private let videoService: VideoService

    private let disposeBag = DisposeBag()

    init(with callService: CallsService,
         callsProvider: CallsProviderDelegate,
         videoService: VideoService) {
        self.callService = callService
        self.callsProvider = callsProvider
        self.videoService = videoService
        self.subscribeCallsEvents()
        VideoAdapter.decodingDelegate = self
    }

    private func subscribeCallsEvents() {
        self.callService.sharedResponseStream
            .filter { event in
                event.eventType == .callEnded
            }
            .subscribe { [weak self] event in
                guard let self = self else { return }
                guard let accountID: String = event.getEventInput(.accountId) else {
                    return
                }
                guard let jamiId: String = event.getEventInput(.uri) else {
                    return
                }
                guard let call = self.callService.call(participantHash: jamiId.filterOutHost(), accountID: accountID) else { return }
                self.callsProvider.stopCall(callUUID: call.callUUID)
                self.videoService.stopCapture()
                self.videoService.setCameraOrientation(orientation: UIDevice.current.orientation)
            } onError: {_ in
            }
            .disposed(by: disposeBag)
    }
}

extension VideoManager: DecodingAdapterDelegate {
    func decodingStarted(withRendererId rendererId: String,
                         withWidth width: Int,
                         withHeight height: Int) {
        guard let call = self.callService.call(callID: rendererId) else { return }
        let codec = self.callService.getVideoCodec(call: call)
        self.videoService.decodingStarted(withRendererId: rendererId, withWidth: width, withHeight: height, withCodec: codec, withaAccountId: call.accountId)
    }
    func decodingStopped(withRendererId rendererId: String) {
        self.videoService.decodingStopped(withRendererId: rendererId)
    }

}
