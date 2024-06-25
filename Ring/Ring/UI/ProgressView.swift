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

import RxCocoa
import RxSwift
import UIKit

class ProgressView: UIView {
    var maximumValue: CGFloat = 100

    var imageView: UIVisualEffectView = .init()
    var statusLabel = UILabel()

    var disposeBug = DisposeBag()
    var status = BehaviorRelay<DataTransferStatus>(value: .ongoing)
    var progressVariable = BehaviorRelay<CGFloat>(value: 0)
    lazy var statusLabelValue: Observable<String> = Observable
        .merge(status.asObservable().map { status in
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
        }, progressVariable
            .asObservable()
            .map { progressValue in
                floor(progressValue)
                    .description.dropLast(2)
                    .description + " %"
            })

    var target: CGFloat = 100

    var currentProgress: CGFloat = 0

    var progress: CGFloat {
        get {
            return innerProgress / toAngleScaler
        }
        set(newProgress) {
            target = newProgress
            currentProgress += (target - currentProgress) * 0.1
            innerProgress = currentProgress * toAngleScaler
            progressVariable.accept(newProgress)
            setImage()
        }
    }

    // MARK: configure path

    private var startPoint: CGPoint {
        return CGPoint(x: bounds.size.width * 0.5, y: 0)
    }

    private var toAngleScaler: CGFloat {
        return 360 / maximumValue
    }

    private var innerProgress: CGFloat = 0.0

    var numberOfCornersInPath: Int {
        return Int(floor((innerProgress + 45) / 90))
    }

    var currentPoint: CGPoint? {
        let valueForSide = maximumValue / 4
        let startValue = valueForSide / 2
        let widthValue = bounds.size.width / valueForSide
        let hightValue = bounds.size.height / valueForSide
        let value = floor((progress + startValue - 1) / valueForSide)
        switch value {
        case 0:
            return CGPoint(x: widthValue * (progress + startValue), y: 0)
        case 1:
            return CGPoint(x: frame.width, y: hightValue * (progress - startValue))
        case 2:
            return CGPoint(x: widthValue * (62.5 - progress), y: frame.height)
        case 3:
            return CGPoint(x: 0, y: hightValue * (87.5 - progress))
        case 4:
            return CGPoint(x: widthValue * (progress - 87.5), y: 0)
        default:
            return nil
        }
    }

    func setImage() {
        let ceneter = CGPoint(x: frame.width * 0.5, y: frame.height * 0.5)
        let progresPath = UIBezierPath()
        progresPath.move(to: startPoint)

        guard let point = currentPoint else { return }
        switch numberOfCornersInPath {
        case 0:
            progresPath.addLine(to: CGPoint(x: 0, y: 0))
            progresPath.addLine(to: CGPoint(x: 0, y: frame.height))
            progresPath.addLine(to: CGPoint(x: frame.width, y: frame.height))
            progresPath.addLine(to: CGPoint(x: frame.width, y: 0))
        case 1:
            progresPath.addLine(to: CGPoint(x: 0, y: 0))
            progresPath.addLine(to: CGPoint(x: 0, y: frame.height))
            progresPath.addLine(to: CGPoint(x: frame.width, y: frame.height))
        case 2:
            progresPath.addLine(to: CGPoint(x: 0, y: 0))
            progresPath.addLine(to: CGPoint(x: 0, y: frame.height))
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

    let maskLayer = CAShapeLayer()

    override func removeFromSuperview() {
        disposeBug = DisposeBag()
        progress = 0.00
        target = 100
        removeSubviews()
        super.removeFromSuperview()
    }

    func configureViews() {
        backgroundColor = UIColor.clear
        layer.cornerRadius = 20
        layer.masksToBounds = true
        let darkBlur = UIBlurEffect(style: UIBlurEffect.Style.dark)
        imageView = UIVisualEffectView(effect: darkBlur)
        imageView.alpha = 0.9
        imageView.frame = bounds
        maskLayer.frame = bounds
        imageView.layer.mask = maskLayer
        addSubview(imageView)
        statusLabel.frame = bounds
        statusLabel.textAlignment = .center
        statusLabel.textColor = UIColor.white
        addSubview(statusLabel)
        disposeBug = DisposeBag()
        statusLabelValue
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak statusLabel] text in
                statusLabel?.text = text
            })
            .disposed(by: disposeBug)
    }
}
