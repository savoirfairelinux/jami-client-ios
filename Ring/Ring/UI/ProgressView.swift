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
    var maximumValue: CGFloat = 100

    var imageView: UIVisualEffectView = UIVisualEffectView()
    var statusLabel = UILabel()

    var disposeBug = DisposeBag()
    var status = Variable<DataTransferStatus>(.ongoing)
    var progressVariable = Variable<CGFloat>(0)
    lazy var statusLabelValue: Observable<String> = {
        return Observable
            .merge( status.asObservable().map({ status in
                switch status {
                case .created, .awaiting, .unknown:
                    return "0 %"
                case .canceled:
                    return L10n.DataTransfer.readableStatusCanceled
                case .error:
                    return L10n.DataTransfer.sendingFailed
                default:
                    return ""
                }
            }), progressVariable
                .asObservable()
                .map({ progressValue in
                return floor(progressValue)
                    .description.dropLast(2)
                    .description + " %"
            }))
    }()

    var target: CGFloat = 100

    var currentProgress: CGFloat = 0

    var progress: CGFloat {
        get {
            return innerProgress / toAngleScaler
        }
        set (newProgress) {
            target = newProgress
            currentProgress += (target - currentProgress) * 0.1
            innerProgress = currentProgress * toAngleScaler
            self.progressVariable.value = newProgress
            setImage()
        }
    }

    // MARK: configure path

    private var startPoint: CGPoint {
        return CGPoint(x: self.bounds.size.width * 0.5, y: 0)
    }

    private var toAngleScaler: CGFloat {
        return 360 / maximumValue
    }

    private var innerProgress: CGFloat = 0.0

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

        guard let point = self.currentPoint else { return }
        switch numberOfCornersInPath {
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
        maskLayer.path = progresPath.cgPath
    }

    let maskLayer = CAShapeLayer.init()

    override func removeFromSuperview() {
        self.disposeBug = DisposeBag()
        self.progress = 0.00
        self.target = 100
        self.removeSubviews()
        super.removeFromSuperview()
    }

    func configureViews() {
        self.backgroundColor = UIColor.clear
        self.layer.cornerRadius = 20
        self.layer.masksToBounds = true
        let darkBlur = UIBlurEffect(style: UIBlurEffect.Style.dark)
        self.imageView = UIVisualEffectView(effect: darkBlur)
        self.imageView.alpha = 0.9
        self.imageView.frame = self.bounds
        maskLayer.frame = self.bounds
        self.imageView.layer.mask = maskLayer
        self.addSubview(self.imageView)
        statusLabel.frame = self.bounds
        statusLabel.textAlignment = .center
        statusLabel.textColor = UIColor.white
        self.addSubview(statusLabel)
        disposeBug = DisposeBag()
        self.statusLabelValue
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak statusLabel] (text) in
                statusLabel?.text = text
            })
            .disposed(by: self.disposeBug)
    }
}
