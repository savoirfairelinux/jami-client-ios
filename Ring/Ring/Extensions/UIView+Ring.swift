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

    @IBInspectable
    var cornerRadius: CGFloat {
        get {
            return self.layer.cornerRadius
        }

        set {
            self.clipsToBounds = true
            self.layer.cornerRadius = newValue
        }
    }

    @IBInspectable
    var roundedCorners: Bool {
        get {
            return self.cornerRadius == self.frame.height / 2
        }

        set {
            if newValue {
                self.cornerRadius = self.frame.height / 2
            } else {
                self.cornerRadius = 0
            }
        }
    }

    @IBInspectable
    var borderWidth: CGFloat {
        get {
            return self.layer.borderWidth
        }

        set {
            self.layer.borderWidth = newValue
        }
    }

    @IBInspectable
    var borderColor: UIColor {
        get {
            return UIColor(cgColor: self.layer.borderColor ?? UIColor.clear.cgColor)
        }

        set {
            self.layer.borderColor = newValue.cgColor
        }
    }

    @IBInspectable
    var gradientStartColor: UIColor {

        get {
            return self.retrieveGradientColor(for: .start)
        }

        set {
            self.applyGradientColor(for: .start, with: newValue)
        }
    }

    @IBInspectable
    var gradientEndColor: UIColor {
        get {
            return self.retrieveGradientColor(for: .end)
        }

        set {
            self.applyGradientColor(for: .end, with: newValue)
        }
    }

    private func applyGradientColor(for anchor: GradientAnchor, with color: UIColor) {
        if let layer = self.layer.sublayers?[0] as? CAGradientLayer {
            // reuse the gradient layer that has already been set
            if anchor == .start {
                layer.colors = [color.cgColor, self.retrieveGradientColor(for: .end).cgColor]
            } else {
                layer.colors = [self.retrieveGradientColor(for: .start).cgColor, color.cgColor]
            }
            return
        }

        let layer = CAGradientLayer()
        layer.frame = CGRect(origin: .zero, size: self.frame.size)
        layer.startPoint = CGPoint(x: 0.5, y: 0)
        layer.endPoint = CGPoint(x: 0.5, y: 1)

        if anchor == .start {
            layer.colors = [color.cgColor, self.retrieveGradientColor(for: .end).cgColor]
        } else {
            layer.colors = [self.retrieveGradientColor(for: .start).cgColor, color.cgColor]
        }
        layer.cornerRadius = self.cornerRadius

        self.layer.addSublayer(layer)

    }

    private func retrieveGradientColor(for anchor: GradientAnchor) -> UIColor {
        if let layer = self.layer.sublayers?[0] as? CAGradientLayer,
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

    func asImage() -> UIImage {
        if #available(iOS 10.0, *) {
            let renderer = UIGraphicsImageRenderer(bounds: bounds)
            return renderer.image { rendererContext in
                layer.render(in: rendererContext.cgContext)
            }
        } else {
            UIGraphicsBeginImageContext(self.frame.size)
            self.layer.render(in: UIGraphicsGetCurrentContext()!)
            let image = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            return UIImage(cgImage: image!.cgImage!)
        }
    }

    func applyGradient(with colours: [UIColor], locations: [NSNumber]? = nil) {
        let gradient = CAGradientLayer()
        gradient.frame = self.bounds
        gradient.colors = colours.map { $0.cgColor }
        gradient.locations = locations
        self.layer.insertSublayer(gradient, at: 0)
    }

    func applyGradient(with colours: [UIColor], gradient orientation: GradientOrientation) {
        let gradient = CAGradientLayer()
        gradient.frame = self.bounds
        gradient.colors = colours.map { $0.cgColor }
        gradient.startPoint = orientation.startPoint
        gradient.endPoint = orientation.endPoint
        self.layer.insertSublayer(gradient, at: 0)
    }

    func updateGradientFrame() {
        let layers = self.layer.sublayers
        if let layer: CAGradientLayer = layers?[0] as? CAGradientLayer {
            layer.frame = self.bounds
        }
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
