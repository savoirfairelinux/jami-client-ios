/*
 *  Copyright (C) 2016-2018 Savoir-faire Linux Inc.
 *
 *  Author: Thibault Wittemberg <thibault.wittemberg@savoirfairelinux.com>
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

import Foundation
import UIKit

private enum GradientAnchor {
    case start
    case end
}

extension UIView {
    @IBInspectable var cornerRadius: CGFloat {
        get {
            return layer.cornerRadius
        }

        set {
            clipsToBounds = true
            layer.cornerRadius = newValue
        }
    }

    @IBInspectable var roundedCorners: Bool {
        get {
            return cornerRadius == frame.height / 2
        }

        set {
            if newValue {
                cornerRadius = frame.height / 2
            } else {
                cornerRadius = 0
            }
        }
    }

    @IBInspectable var borderWidth: CGFloat {
        get {
            return layer.borderWidth
        }

        set {
            layer.borderWidth = newValue
        }
    }

    @IBInspectable var borderColor: UIColor {
        get {
            return UIColor(cgColor: layer.borderColor ?? UIColor.clear.cgColor)
        }

        set {
            layer.borderColor = newValue.cgColor
        }
    }

    @IBInspectable var gradientStartColor: UIColor {
        get {
            return retrieveGradientColor(for: .start)
        }

        set {
            applyGradientColor(for: .start, with: newValue)
        }
    }

    @IBInspectable var gradientEndColor: UIColor {
        get {
            return retrieveGradientColor(for: .end)
        }

        set {
            applyGradientColor(for: .end, with: newValue)
        }
    }

    private func applyGradientColor(for anchor: GradientAnchor, with color: UIColor) {
        if let layer = self.layer.sublayers?[0] as? CAGradientLayer {
            // reuse the gradient layer that has already been set
            if anchor == .start {
                layer.colors = [color.cgColor, retrieveGradientColor(for: .end).cgColor]
            } else {
                layer.colors = [retrieveGradientColor(for: .start).cgColor, color.cgColor]
            }
            return
        }

        let layer = CAGradientLayer()
        layer.frame = CGRect(origin: .zero, size: frame.size)
        layer.startPoint = CGPoint(x: 0.5, y: 0)
        layer.endPoint = CGPoint(x: 0.5, y: 1)

        if anchor == .start {
            layer.colors = [color.cgColor, retrieveGradientColor(for: .end).cgColor]
        } else {
            layer.colors = [retrieveGradientColor(for: .start).cgColor, color.cgColor]
        }
        layer.cornerRadius = cornerRadius

        self.layer.addSublayer(layer)
    }

    private func retrieveGradientColor(for anchor: GradientAnchor) -> UIColor {
        if let layer = layer.sublayers?[0] as? CAGradientLayer,
           let colors = layer.colors as? [CGColor] {
            if anchor == .start && !colors.isEmpty {
                return UIColor(cgColor: colors[0])
            }

            if anchor == .end && colors.count >= 1 {
                return UIColor(cgColor: colors[1])
            }

            return UIColor.clear
        }

        return UIColor.clear
    }

    func convertToImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        return renderer.image { rendererContext in
            layer.render(in: rendererContext.cgContext)
        }
    }

    var isRightToLeft: Bool {
        return effectiveUserInterfaceLayoutDirection == .rightToLeft
    }

    func applyGradient(with colours: [UIColor], locations: [NSNumber]? = nil) {
        let gradient = CAGradientLayer()
        gradient.frame = bounds
        gradient.colors = colours.map { $0.cgColor }
        gradient.locations = locations
        layer.insertSublayer(gradient, at: 0)
    }

    func applyGradient(with colours: [UIColor], gradient orientation: GradientOrientation) {
        let gradient = CAGradientLayer()
        gradient.frame = bounds
        gradient.colors = colours.map { $0.cgColor }
        gradient.startPoint = orientation.startPoint
        gradient.endPoint = orientation.endPoint
        layer.insertSublayer(gradient, at: 0)
    }

    func updateGradientFrame() {
        let layers = layer.sublayers
        if let layer: CAGradientLayer = layers?[0] as? CAGradientLayer {
            layer.frame = bounds
        }
    }

    func roundTopCorners(radius: CGFloat) {
        let path = UIBezierPath(
            roundedRect: bounds,
            byRoundingCorners: [.topLeft, .topRight],
            cornerRadii: CGSize(width: radius, height: radius)
        )
        let mask = CAShapeLayer()
        mask.path = path.cgPath
        mask.frame = bounds
        layer.mask = mask
    }

    func roundAllCorners(radius: CGFloat) {
        let path = UIBezierPath(
            roundedRect: bounds,
            byRoundingCorners: [.bottomLeft, .bottomRight, .topRight, .topLeft],
            cornerRadii: CGSize(width: radius, height: radius)
        )
        let mask = CAShapeLayer()
        mask.path = path.cgPath
        mask.frame = bounds
        layer.mask = mask
    }

    func removeCorners() {
        layer.mask = nil
    }

    func blink() {
        UIView.animate(withDuration: 1,
                       delay: 0.0,
                       options: [.curveEaseInOut,
                                 .autoreverse,
                                 .repeat],
                       animations: { [weak self] in
                        self?.alpha = 0.4
                       },
                       completion: { [weak self] _ in
                        self?.alpha = 1.0
                       })
    }

    func stopBlinking() {
        layer.removeAllAnimations()
        alpha = 1.0 // Reset to full opacity
    }

    func removeSubviews(recursive: Bool = false) {
        for subview in subviews {
            if recursive {
                subview.removeSubviews(recursive: recursive)
            }
            subview.removeFromSuperview()
        }
    }

    func setBorderPadding(left: CGFloat, right: CGFloat, top: CGFloat, bottom: CGFloat) {
        let frame = bounds.inset(by: UIEdgeInsets(
            top: top,
            left: left,
            bottom: bottom,
            right: right
        ))
        let circlePath = UIBezierPath(roundedRect: frame, cornerRadius: cornerRadius)
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = circlePath.cgPath
        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.strokeColor = borderColor.cgColor
        shapeLayer.lineWidth = borderWidth
        layer.addSublayer(shapeLayer)
        borderWidth = 0
    }
}

typealias GradientPoints = (startPoint: CGPoint, endPoint: CGPoint)

enum GradientOrientation {
    case topRightBottomLeft
    case topLeftBottomRight
    case horizontal
    case vertical

    var startPoint: CGPoint {
        return points.startPoint
    }

    var endPoint: CGPoint {
        return points.endPoint
    }

    var points: GradientPoints {
        switch self {
        case .topRightBottomLeft:
            return (CGPoint(x: 0.0, y: 1.0), CGPoint(x: 1.0, y: 0.0))
        case .topLeftBottomRight:
            return (CGPoint(x: 0.0, y: 0.0), CGPoint(x: 1, y: 1))
        case .horizontal:
            return (CGPoint(x: 0.0, y: 0.5), CGPoint(x: 1.0, y: 0.5))
        case .vertical:
            return (CGPoint(x: 0.0, y: 0.0), CGPoint(x: 0.0, y: 1.0))
        }
    }
}
