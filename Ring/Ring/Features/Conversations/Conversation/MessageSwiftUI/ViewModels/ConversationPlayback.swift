/*
 * Copyright (C) 2026 Savoir-faire Linux Inc.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA.
 */

import Foundation
import RxSwift
import RxRelay

struct PlaybackItem: Equatable {
    let id: String
    let url: URL
    let preview: MediaPreview
}

struct ActivePlayback {
    let itemId: String
    let player: PlayerViewModel
}

struct MessageMedia {
    let item: PlaybackItem
    weak var playback: ConversationPlayback?
}

final class ConversationPlayback {

    let active = BehaviorRelay<ActivePlayback?>(value: nil)
    let playbackStarted = PublishSubject<Void>()

    private let videoService: VideoService
    private var activeDisposeBag = DisposeBag()

    init(videoService: VideoService) {
        self.videoService = videoService
    }

    deinit {
        active.value?.player.close()
    }

    func togglePlay(_ item: PlaybackItem) {
        if let current = active.value, current.itemId == item.id {
            current.player.togglePause()
            return
        }
        stop()
        let player = PlayerViewModel(path: item.url.path, preview: item.preview, videoService: videoService)
        player.isPaused
            .distinctUntilChanged()
            .skip(1)
            .filter { !$0 }
            .map { _ in }
            .bind(to: playbackStarted)
            .disposed(by: activeDisposeBag)
        active.accept(ActivePlayback(itemId: item.id, player: player))
        player.togglePause()
    }

    func player(for itemId: String) -> PlayerViewModel? {
        guard let current = active.value, current.itemId == itemId else { return nil }
        return current.player
    }

    func pause() {
        active.value?.player.pauseIfPlaying()
    }

    func stop() {
        guard let current = active.value else { return }
        activeDisposeBag = DisposeBag()
        current.player.close()
        active.accept(nil)
    }
}
