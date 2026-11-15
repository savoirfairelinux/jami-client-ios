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

import UIKit

struct CanvasTileModel {
    let participant: CanvasParticipant
    let tileState: ParticipantTileState
    let distributor: FrameDistributor?
    let fixedTransform: CGAffineTransform?
    let avatarProvider: AvatarProvider?
    let expectedVideoSize: CGSize?

    init(participant: CanvasParticipant,
         tileState: ParticipantTileState,
         distributor: FrameDistributor? = nil,
         fixedTransform: CGAffineTransform? = nil,
         avatarProvider: AvatarProvider? = nil,
         expectedVideoSize: CGSize? = nil) {
        self.participant = participant
        self.tileState = tileState
        self.distributor = distributor
        self.fixedTransform = fixedTransform
        self.avatarProvider = avatarProvider
        self.expectedVideoSize = expectedVideoSize
    }
}

extension CanvasTileModel: Equatable {
    static func == (lhs: CanvasTileModel, rhs: CanvasTileModel) -> Bool {
        return lhs.participant == rhs.participant
            && lhs.tileState == rhs.tileState
            && lhs.fixedTransform == rhs.fixedTransform
            && lhs.distributor === rhs.distributor
            && lhs.avatarProvider === rhs.avatarProvider
            && lhs.expectedVideoSize == rhs.expectedVideoSize
    }
}
