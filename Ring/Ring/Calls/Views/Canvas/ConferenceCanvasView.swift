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

    func makeUIView(context: Context) -> ParticipantCanvas {
        let canvas = ParticipantCanvas()
        canvas.onCanvasTapped = { [weak model] in
            model?.screenTapped()
        }
        canvas.onTileLongPressed = { [weak model] id in
            model?.tileTapped(id)
        }
        return canvas
    }

    func updateUIView(_ canvas: ParticipantCanvas, context: Context) {
        canvas.apply(models: model.canvas.tiles, mode: model.canvas.mode)
    }
}
