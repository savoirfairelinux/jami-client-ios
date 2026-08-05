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

final class PreviewDockHandleView: UIControl {

    enum Metrics {
        static let hitSize = CGSize(width: 44, height: 64)
        static let visibleWidth: CGFloat = 28
        static let cornerRadius: CGFloat = 14
    }

    private let effectView = UIVisualEffectView(
        effect: UIBlurEffect(style: .systemThinMaterialDark))
    private let tintView = UIView()
    private let arrowView = UIImageView()
    private var side = PreviewDockSide.left

    override init(frame: CGRect) {
        super.init(frame: frame)
        isAccessibilityElement = true
        accessibilityTraits = .button

        layer.shadowColor = UIColor.jamiOnVideoScrim.cgColor
        layer.shadowOpacity = 0.7
        layer.shadowRadius = 8
        layer.shadowOffset = .zero

        effectView.isUserInteractionEnabled = false
        effectView.clipsToBounds = true
        effectView.layer.cornerRadius = Metrics.cornerRadius
        addSubview(effectView)

        tintView.backgroundColor = .jamiOnVideoGlass
        tintView.isUserInteractionEnabled = false
        effectView.contentView.addSubview(tintView)

        arrowView.contentMode = .center
        arrowView.tintColor = .white
        arrowView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(
            pointSize: 17, weight: .semibold)
        arrowView.isAccessibilityElement = false
        effectView.contentView.addSubview(arrowView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func configure(side: PreviewDockSide) {
        self.side = side
        accessibilityLabel = L10n.Accessibility.Conference.showLocalPreview
        arrowView.image = UIImage(systemName: side == .left
                                    ? "chevron.right" : "chevron.left")
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let visualX = side == .left ? 0 : bounds.width - Metrics.visibleWidth
        effectView.frame = CGRect(x: visualX, y: 0,
                                  width: Metrics.visibleWidth, height: bounds.height)
        tintView.frame = effectView.bounds
        arrowView.frame = effectView.bounds
        effectView.layer.maskedCorners = side == .left
            ? [.layerMaxXMinYCorner, .layerMaxXMaxYCorner]
            : [.layerMinXMinYCorner, .layerMinXMaxYCorner]
        layer.shadowPath = UIBezierPath(roundedRect: effectView.frame,
                                        cornerRadius: Metrics.cornerRadius).cgPath
    }
}
