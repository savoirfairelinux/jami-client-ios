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

enum VideoScalingPolicy: Equatable {
    case aspectFill
    case aspectFit
    case automatic
}

enum VideoScaling {

    private static let aspectRatioMismatchThreshold: CGFloat = 1.3

    static func shouldShowWholeFrame(
        videoSize: CGSize,
        transform: CGAffineTransform,
        tileSize: CGSize,
        policy: VideoScalingPolicy
    ) -> Bool {
        switch policy {
        case .aspectFill:
            return false
        case .aspectFit:
            return true
        case .automatic:
            break
        }
        guard let mismatchFactor = aspectRatioMismatchFactor(
            videoSize: videoSize, transform: transform, tileSize: tileSize
        ) else {
            return false
        }
        return mismatchFactor > Self.aspectRatioMismatchThreshold
    }

    private static func aspectRatioMismatchFactor(
        videoSize: CGSize,
        transform: CGAffineTransform,
        tileSize: CGSize
    ) -> CGFloat? {
        let orientedSize = orientedVideoSize(videoSize: videoSize, transform: transform)
        guard orientedSize.width > 0, orientedSize.height > 0,
              tileSize.width > 0, tileSize.height > 0 else {
            return nil
        }
        let videoAspectRatio = orientedSize.width / orientedSize.height
        let tileAspectRatio = tileSize.width / tileSize.height
        return max(videoAspectRatio / tileAspectRatio, tileAspectRatio / videoAspectRatio)
    }

    private static func orientedVideoSize(videoSize: CGSize,
                                          transform: CGAffineTransform) -> CGSize {
        transform.isQuarterTurn
            ? CGSize(width: videoSize.height, height: videoSize.width)
            : videoSize
    }
}
