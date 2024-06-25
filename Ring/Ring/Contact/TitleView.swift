/*
 *  Copyright (C) 2018-2019 Savoir-faire Linux Inc.
 *
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
 *  Author: Quentin Muret <quentin.muret@savoirfairelinux.com>
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

import RxSwift
import UIKit

// swiftlint:disable identifier_name

final class TitleView: UIView {
    private let containerView = UIView()
    private let avatarView = UIView()
    private let label = UILabel()
    private var contentOffset: CGFloat = 0 {
        didSet {
            containerView.frame.origin.y = titleVerticalPositionAdjusted(by: contentOffset)
            let midY = bounds.midY - containerView.bounds.height * 0.5
            let value = max(bounds.maxY - contentOffset, midY).rounded()
            let alpha = midY * (1 / value)
            containerView.alpha = alpha
        }
    }

    var avatarImage: UIView = .init() {
        didSet {
            avatarView.subviews.forEach { $0.removeFromSuperview() }
            avatarView.addSubview(avatarImage)
            layoutSubviews()
        }
    }

    var text: String = "" {
        didSet {
            label.text = text
            layoutSubviews()
        }
    }

    // MARK: Initializers

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(containerView)
        containerView.addSubview(avatarView)
        containerView.addSubview(label)
        label.textColor = UIColor.jamiSecondary
        label.font = UIFont.systemFont(ofSize: 17.0, weight: .regular)
        clipsToBounds = true
        isUserInteractionEnabled = false
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        sizeToFit()
    }

    private func layoutSubviews11() {
        let margin: CGFloat = 10
        let maxNameWidth: CGFloat = 120.0
        let x: CGFloat
        let y: CGFloat
        let sizeLabel = label.sizeThatFits(bounds.size)
        let labelWidth = min(sizeLabel.width, maxNameWidth)
        let sizeImage = avatarImage.sizeThatFits(bounds.size)
        let totalWidth: CGFloat = labelWidth + sizeImage.width + margin

        x = bounds.midX - totalWidth * 0.5

        if contentOffset == 0 {
            y = bounds.maxY
        } else {
            y = titleVerticalPositionAdjusted(by: contentOffset)
        }

        avatarView.frame = CGRect(x: 0, y: 0, width: sizeImage.width, height: sizeImage.height)
        label.frame = CGRect(
            x: sizeImage.width + margin,
            y: 0,
            width: labelWidth,
            height: sizeImage.height
        )
        containerView.frame = CGRect(x: x, y: y, width: totalWidth, height: sizeImage.height)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutSubviews11()
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView, threshold: CGFloat = 0) {
        contentOffset = scrollView.contentOffset.y + threshold
    }

    // MARK: Private

    private func titleVerticalPositionAdjusted(by yOffset: CGFloat) -> CGFloat {
        let midY = bounds.midY - containerView.bounds.height * 0.5
        return max(bounds.maxY - yOffset, midY).rounded()
    }
}

private extension UIView {
    func typedSuperview<T: UIView>() -> T? {
        var parent = superview

        while parent != nil {
            if let view = parent as? T {
                return view
            } else {
                parent = parent?.superview
            }
        }
        return nil
    }
}
