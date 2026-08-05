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

import UIKit

enum PreviewDocking {
    private static let outwardFlingVelocity: CGFloat = 650
    private static let restoreDistance: CGFloat = 32
    private static let inwardFlingVelocity: CGFloat = 500
    private static let dockDistanceFraction: CGFloat = 1.0 / 3.0
    private static let rubberBandCoefficient: CGFloat = 0.55

    static func shouldDock(outwardDistance: CGFloat,
                           outwardVelocity: CGFloat,
                           previewWidth: CGFloat) -> Bool {
        return outwardDistance >= previewWidth * dockDistanceFraction
            || outwardVelocity >= outwardFlingVelocity
    }

    static func shouldRestore(inwardDistance: CGFloat,
                              inwardVelocity: CGFloat) -> Bool {
        return inwardDistance >= restoreDistance
            || inwardVelocity >= inwardFlingVelocity
    }

    static func rubberBanded(_ distance: CGFloat, dimension: CGFloat) -> CGFloat {
        guard distance > 0, dimension > 0 else { return 0 }
        return (1 - 1 / (distance * rubberBandCoefficient / dimension + 1)) * dimension
    }

    static func handleOrigin(for side: PreviewDockSide,
                             previewVisualRect: CGRect,
                             hitSize: CGSize) -> CGPoint {
        switch side {
        case .left:
            return CGPoint(x: previewVisualRect.maxX,
                           y: previewVisualRect.midY - hitSize.height / 2)
        case .right:
            return CGPoint(x: previewVisualRect.minX - hitSize.width,
                           y: previewVisualRect.midY - hitSize.height / 2)
        }
    }
}
