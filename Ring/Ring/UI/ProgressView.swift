/*
 *  Copyright (C) 2019 Savoir-faire Linux Inc.
 *
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
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
import RxSwift

class ProgressView: UIView {
    var imageView: UIImageView = UIImageView()
    var statusLabel = UILabel()

    var statusDisposeBug = DisposeBag()
    var maximumValue: CGFloat = 100
    var status = Variable<DataTransferStatus>(.ongoing)
    var progressVariable = Variable<CGFloat>(0)
    lazy var statusLabelValue: Observable<String> = {
        return Observable
            .of(status.asObservable().map({ status in
                switch status {
                case .created,.awaiting:
                    return "0 %"
                case .canceled:
                    return "cancelled"
                case .error, .unknown:
                    return "not sent"
                default:
                    return ""
                }
            }),
                progressVariable.asObservable().map({ progressValue in
                    return floor(progressValue)
                        .description.dropLast(2)
                        .description + " %"
                }))
            .switchLatest()
    }()
    var image: UIImage? {
        didSet {
            guard let image = image else {return}
            if bluredImage != nil {return}
            let context = CIContext(options: nil)
            let inputImage = CIImage(image: image)
            let originalOrientation = image.imageOrientation
            let originalScale = image.scale
            let filterColor = CIFilter(name: "CIExposureAdjust")
            filterColor?.setValue(-2, forKey: "inputEV")
            filterColor?.setValue(inputImage, forKey: kCIInputImageKey)
            let filterGausse = CIFilter(name: "CIGaussianBlur")
            let filterClamp = CIFilter(name: "CIAffineClamp")
            filterClamp?.setValue(filterColor?.outputImage, forKey: kCIInputImageKey)
            filterGausse?.setValue(6.0, forKey: kCIInputRadiusKey)
            filterGausse?.setValue(filterClamp?.outputImage, forKey: kCIInputImageKey)
            let outputImage = filterGausse?.outputImage
            var cgImage:CGImage?
            if let asd = outputImage
            {
                cgImage = context.createCGImage(asd, from: (inputImage?.extent)!)
            }
            if let cgImageA = cgImage
            {
                let outputimage = UIImage(cgImage: cgImageA, scale: originalScale, orientation: originalOrientation)
                self.layer.cornerRadius = 20
                self.layer.masksToBounds = true
                bluredImage = outputimage
                self.imageView.frame = self.bounds
                self.imageView.image = bluredImage
                self.addSubview(self.imageView)
                statusLabel.frame = self.bounds
                statusLabel.textAlignment = .center
                statusLabel.textColor = UIColor.white
                self.addSubview(statusLabel)
                statusDisposeBug = DisposeBag()
                self.statusLabelValue
                    .observeOn(MainScheduler.instance)
                    .bind(to: statusLabel.rx.text)
                    .disposed(by: self.statusDisposeBug)
            }
        }
    }
    private var startPoint: CGPoint {
        return CGPoint(x: self.bounds.size.width * 0.5, y: 0)
    }

    var bluredImage: UIImage?

    private var toAngleScaler: CGFloat {
        return 360 / maximumValue
    }

    private var innerProgress: CGFloat = 0.0

    var progress : CGFloat {
        set (newProgress) {
            innerProgress = newProgress * toAngleScaler
            self.progressVariable.value = newProgress
            setImage()
        }
        get {
            return innerProgress / toAngleScaler
        }
    }

    var numberOfCornersInPath: Int {
        return Int(floor((self.innerProgress + 45) / 90))
    }

    var currentPoint: CGPoint? {
        let valueForSide = maximumValue / 4
        let startValue = valueForSide / 2
        let widthValue = self.bounds.size.width / valueForSide
        let hightValue = self.bounds.size.height / valueForSide
        let value = floor((progress + startValue - 1 ) / valueForSide)
        switch value {
        case 0 :
            return CGPoint(x: widthValue * (progress + startValue), y: 0)
        case 1:
            return CGPoint(x: self.frame.width, y: hightValue * (progress - startValue))
        case 2 :
            return CGPoint(x: widthValue * (62.5 - progress), y: self.frame.height)
        case 3:
            return CGPoint(x: 0, y: hightValue * (87.5 - progress))
        case 4:
            return CGPoint(x: widthValue * (progress - 87.5), y: 0)
        default:
            return nil
        }
    }

    func setImage() {
        let ceneter = CGPoint(x: self.frame.width * 0.5, y: self.frame.height * 0.5)
        let progresPath: UIBezierPath = UIBezierPath()
        progresPath.move(to: startPoint)

        guard let point = self.currentPoint else {return}
        switch self.numberOfCornersInPath {
        case 0:
            progresPath.addLine(to: CGPoint(x: 0, y: 0))
            progresPath.addLine(to: CGPoint(x: 0, y: self.frame.height))
            progresPath.addLine(to: CGPoint(x: self.frame.width, y: self.frame.height))
            progresPath.addLine(to: CGPoint(x: self.frame.width, y: 0))
        case 1:
            progresPath.addLine(to: CGPoint(x: 0, y: 0))
            progresPath.addLine(to: CGPoint(x: 0, y: self.frame.height))
            progresPath.addLine(to: CGPoint(x: self.frame.width, y: self.frame.height))

        case 2:
            progresPath.addLine(to: CGPoint(x: 0, y: 0))
            progresPath.addLine(to: CGPoint(x: 0, y: self.frame.height))
        case 3:
            progresPath.addLine(to: CGPoint(x: 0, y: 0))
        default:
            break
        }
        progresPath.addLine(to: point)
        progresPath.addLine(to: ceneter)
        progresPath.close()
        let maskLayer = CAShapeLayer.init();

        maskLayer.frame = self.bounds;

        maskLayer.path = progresPath.cgPath;
        self.imageView.removeFromSuperview();
        self.imageView.frame = self.bounds
        self.imageView.image = bluredImage

        self.imageView.layer.mask = maskLayer
        self.addSubview(self.imageView)
        self.bringSubviewToFront(statusLabel)
    }

    func shapeImageWithBezierPath(bezierPath: UIBezierPath, fillColor: UIColor?, strokeColor: UIColor?, strokeWidth: CGFloat = 1.0) -> UIImage! {
        bezierPath.apply(CGAffineTransform(translationX: -bezierPath.bounds.origin.x, y: -bezierPath.bounds.origin.y ) )
        let size = self.frame.size
        UIGraphicsBeginImageContext(size)
        let context = UIGraphicsGetCurrentContext()
        var image = self.bluredImage
        if let context  = context {
            context.saveGState()
            context.addPath(bezierPath.cgPath)
            if strokeColor != nil {
                strokeColor!.setStroke()
                context.setLineWidth(strokeWidth)
            } else { UIColor.clear.setStroke() }
            fillColor?.setFill()
            context.drawPath(using: .fillStroke)
            image = UIGraphicsGetImageFromCurrentImageContext()!
            context.restoreGState()
            UIGraphicsEndImageContext()
        }
        return image
    }

    override func removeFromSuperview() {
        self.subviews.forEach { view in
            view.removeFromSuperview()
        }
        self.image = nil
        self.bluredImage = nil
        self.statusDisposeBug = DisposeBag()
        super.removeFromSuperview()
    }
}
