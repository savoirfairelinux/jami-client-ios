/*
 *  Copyright (C) 2022 Savoir-faire Linux Inc.
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

import SwiftUI
import RxSwift

struct PlayerViewWrapper: UIViewRepresentable {
    typealias UIViewType = PlayerView

    var viewModel: PlayerViewModel
    var width: CGFloat
    var height: CGFloat
    let onLongGesture: () -> Void
    let disposeBag = DisposeBag()
    let longGestureRecognizer = UILongPressGestureRecognizer()

    func makeUIView(context: Context) -> PlayerView {
        let frame = CGRect(x: 0, y: 0, width: width, height: height)
        let player = PlayerView(frame: frame)
        player.viewModel = viewModel
        longGestureRecognizer.rx
            .event
            .filter({ event in
                event.state == UIGestureRecognizer.State.began
            })
            .bind(onNext: { _ in
                self.onLongGesture()
            })
            .disposed(by: self.disposeBag)
        longGestureRecognizer.minimumPressDuration = 0.2
        player.addGestureRecognizer(longGestureRecognizer)
        return player
    }

    func updateUIView(_ uiView: PlayerView, context: Context) {
        let newFrame = CGRect(x: 0, y: 0, width: width, height: height)
        uiView.frame = newFrame
        uiView.frameUpdated()
    }
}

struct PlayerSwiftUI: View {
    @StateObject var model: MessageContentVM
    var player: PlayerViewModel
    let onLongGesture: () -> Void
    var body: some View {
        PlayerViewWrapper.init(viewModel: player, width: model.playerWidth, height: model.playerHeight, onLongGesture: onLongGesture)
            .frame(height: model.playerHeight)
            .frame(width: model.playerWidth)
    }
}
