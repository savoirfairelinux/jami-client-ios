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

struct PlayerViewWrapper: UIViewRepresentable {
    typealias UIViewType = PlayerView

    var viewModel: PlayerViewModel
    var width: CGFloat
    var height: CGFloat

    func makeUIView(context: Context) -> PlayerView {
        let frame = CGRect(x: 0, y: 0, width: width, height: height)
        let player = PlayerView(frame: frame)
        player.viewModel = viewModel
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
    var body: some View {
        PlayerViewWrapper.init(viewModel: player, width: model.playerWidth, height: model.playerHeight)
            .frame(height: model.playerHeight)
            .frame(width: model.playerWidth)
    }
}
