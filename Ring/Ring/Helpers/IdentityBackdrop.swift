/*
 *  Copyright (C) 2026-2026 Savoir-faire Linux Inc.
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

import UIKit
import CoreImage

enum IdentityBackdrop {

    /// Both points sit outside the tile, so only the shoulder of the falloff lands on it.
    enum Geometry {
        /// Positions for `falloff`; same length.
        static let locations: [NSNumber] = [0, 0.30, 0.55, 0.78, 1]

        private static let source = CGPoint(x: 0.10, y: -0.10)
        private static let reach = CGPoint(x: 1.65, y: 1.45)

        /// `end` carries the radial's radius, not a direction, so it follows the
        /// mirrored origin instead of being mirrored itself.
        static func points(mirrored: Bool) -> (start: CGPoint, end: CGPoint) {
            let start = mirrored ? CGPoint(x: 1 - source.x, y: source.y) : source
            let end = CGPoint(x: start.x + reach.x - source.x,
                              y: start.y + reach.y - source.y)
            return (start, end)
        }
    }

    private enum Metrics {
        /// Ceiling on how much hue reaches the screen — white chrome sits over it.
        static let peakAlpha: CGFloat = 0.14
        static let minSaturation: CGFloat = 0.10
        /// Averaging pulls toward grey; the hue needs boosting to survive `peakAlpha`.
        static let tintSaturation: CGFloat = 0.65
    }

    /// Five stops, not two: CAGradientLayer interpolates linearly, and a single ramp
    /// shows an edge where the rate changes.
    private static let falloff: [CGFloat] = [1, 0.72, 0.40, 0.15, 0]

    static func photoTint(for avatar: UIImage) -> UIColor? {
        averageColor(of: avatar).map(saturated)
    }

    static func monogramTint(forName name: String) -> UIColor? {
        name.isEmpty ? nil : avatarBackgroundColor(for: name)
    }

    static func gradientColors(for tint: UIColor) -> [CGColor] {
        falloff.map { tint.withAlphaComponent(Metrics.peakAlpha * $0).cgColor }
    }

    private static let context = CIContext(options: [.workingColorSpace: NSNull(),
                                                     .cacheIntermediates: false])

    private static func averageColor(of image: UIImage) -> UIColor? {
        guard let input = CIImage(image: image) else { return nil }
        let extent = CIVector(x: input.extent.origin.x, y: input.extent.origin.y,
                              z: input.extent.size.width, w: input.extent.size.height)
        guard let filter = CIFilter(name: "CIAreaAverage",
                                    parameters: [kCIInputImageKey: input,
                                                 kCIInputExtentKey: extent]),
              let output = filter.outputImage else { return nil }

        var pixel = [UInt8](repeating: 0, count: 4)
        context.render(output,
                       toBitmap: &pixel,
                       rowBytes: 4,
                       bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                       format: .RGBA8,
                       colorSpace: nil)
        let scale: CGFloat = 255
        return UIColor(red: CGFloat(pixel[0]) / scale,
                       green: CGFloat(pixel[1]) / scale,
                       blue: CGFloat(pixel[2]) / scale,
                       alpha: 1)
    }

    private static func saturated(_ color: UIColor) -> UIColor {
        var hue: CGFloat = 0, saturation: CGFloat = 0
        var brightness: CGFloat = 0, alpha: CGFloat = 0
        guard color.getHue(&hue, saturation: &saturation,
                           brightness: &brightness, alpha: &alpha),
              saturation > Metrics.minSaturation else { return color }
        return UIColor(hue: hue,
                       saturation: max(saturation, Metrics.tintSaturation),
                       brightness: 1,
                       alpha: 1)
    }
}
