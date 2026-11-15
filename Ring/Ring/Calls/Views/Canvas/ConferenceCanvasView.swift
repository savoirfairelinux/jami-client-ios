/*
 * Copyright (C) 2019-2026 Savoir-faire Linux Inc.
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

import SwiftUI

struct ConferenceCanvasView: UIViewRepresentable {

    @ObservedObject var model: CallViewModel
    let previewControlInsets: UIEdgeInsets
    let previewHeaderClearance: CGFloat
    let scrimClearance: UIEdgeInsets
    let showsScrims: Bool

    func makeUIView(context: Context) -> ParticipantCanvas {
        let canvas = ParticipantCanvas()
        canvas.onCanvasTapped = { [weak model] in
            model?.screenTapped()
        }
        canvas.onTileLongPressed = { [weak model] id in
            model?.tileTapped(id)
        }
        canvas.onVideoScalingChosen = { [weak model] policy, id in
            model?.videoScalingChosen(policy, forTileId: id)
        }
        canvas.onPrimaryVideoChanged = { [weak model] video in
            DispatchQueue.main.async { model?.primaryVideoChanged(video) }
        }
        return canvas
    }

    func updateUIView(_ canvas: ParticipantCanvas, context: Context) {
        canvas.previewHeaderClearance = previewHeaderClearance
        canvas.scrimClearance = scrimClearance
        canvas.showsScrims = showsScrims
        canvas.previewControlInsets = previewControlInsets
        canvas.apply(model.canvas)
    }
}
