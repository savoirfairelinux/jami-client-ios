/*
 * Copyright (C) 2026-2026 Savoir-faire Linux Inc.
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

/// Darkens the video behind the call chrome. Each band covers the chrome's
/// clearance and then fades over the same distance again.
final class CanvasScrimView: UIView {

    private enum Metrics {
        static let topOpacity: CGFloat = 0.42
        static let bottomOpacity: CGFloat = 0.35
        static let ramp: [CGFloat] = [0, 0.16, 0.5, 0.84, 1]
    }

    var clearance = UIEdgeInsets.zero {
        didSet {
            guard clearance != oldValue else { return }
            setNeedsLayout()
        }
    }

    private let top = GradientBand(colors: CanvasScrimView.colors(opacity: Metrics.topOpacity).reversed())
    private let bottom = GradientBand(colors: CanvasScrimView.colors(opacity: Metrics.bottomOpacity))

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        addSubview(top)
        addSubview(bottom)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let topHeight = bandHeight(inset: safeAreaInsets.top, clearance: clearance.top)
        let bottomHeight = bandHeight(inset: safeAreaInsets.bottom, clearance: clearance.bottom)
        top.frame = CGRect(x: 0, y: 0, width: bounds.width, height: topHeight)
        bottom.frame = CGRect(x: 0, y: bounds.height - bottomHeight,
                              width: bounds.width, height: bottomHeight)
    }

    private func bandHeight(inset: CGFloat, clearance: CGFloat) -> CGFloat {
        inset + CanvasLayout.previewPadding + 2 * clearance
    }

    private static func colors(opacity: CGFloat) -> [CGColor] {
        Metrics.ramp.map { UIColor.black.withAlphaComponent(opacity * $0).cgColor }
    }
}

private final class GradientBand: UIView {

    override static var layerClass: AnyClass { CAGradientLayer.self }

    init(colors: [CGColor]) {
        super.init(frame: .zero)
        guard let gradient = layer as? CAGradientLayer else { return }
        gradient.colors = colors
        gradient.locations = colors.indices.map {
            NSNumber(value: Double($0) / Double(colors.count - 1))
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }
}
