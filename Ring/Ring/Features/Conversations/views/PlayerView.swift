/*
*  Copyright (C) 2020 Savoir-faire Linux Inc.
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
import Reusable
import RxSwift

class PlayerView: UIView {
    @IBOutlet var containerView: UIView!
    @IBOutlet weak var incomingImage: UIImageView!
    @IBOutlet weak var togglePause: UIButton!
    @IBOutlet weak var muteAudio: UIButton!
    @IBOutlet weak var resizeView: UIButton!
    @IBOutlet weak var progressSlider: UISlider!
    @IBOutlet weak var durationLabel: UILabel!

    var viewModel: PlayerViewModel!

    let disposeBag = DisposeBag()

    var sliderDisposeBag = DisposeBag()

    @IBAction func startSeekFrame(_ sender: Any) {
        sliderDisposeBag = DisposeBag()
        self.viewModel.userStartSeeking()
        progressSlider.rx.value
            .subscribe(onNext: { [weak self] (value) in
                self?.viewModel.seekTimeVariable.value = Float(value)
            })
            .disposed(by: self.sliderDisposeBag)
    }

    @IBAction func stopSeekFrame(_ sender: UISlider) {
        sliderDisposeBag = DisposeBag()
        self.viewModel.userStopSeeking()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.commonInit()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.commonInit()
    }

    func commonInit() {
        Bundle.main.loadNibNamed("PlayerView", owner: self, options: nil)
        addSubview(containerView)
        containerView.frame = self.bounds
        let circleImage = makeCircleWith(size: CGSize(width: 15, height: 15),
                                         backgroundColor: UIColor.white)
        progressSlider.setThumbImage(circleImage, for: .normal)
        progressSlider.setThumbImage(circleImage, for: .highlighted)
    }

    private func makeCircleWith(size: CGSize, backgroundColor: UIColor) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        let context = UIGraphicsGetCurrentContext()
        context?.setFillColor(backgroundColor.cgColor)
        context?.setStrokeColor(UIColor.clear.cgColor)
        let bounds = CGRect(origin: .zero, size: size)
        context?.addEllipse(in: bounds)
        context?.drawPath(using: .fill)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }

    override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)
        bindViews()
        viewModel.createPlayer()
    }

    func bindViews() {
        self.viewModel.playBackFrame
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] frame in
                if let image = frame {
                    DispatchQueue.main.async {
                        self?.incomingImage.image = image
                    }
                }
            })
            .disposed(by: self.disposeBag)
        self.viewModel.playerPosition
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] position in
                self?.progressSlider.value = position
            })
            .disposed(by: self.disposeBag)
        self.viewModel.playerDuration
            .asObservable()
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] duration in
                let durationString = self?.durationString(microcec: duration) ?? ""
                self?.durationLabel.text = durationString
            })
            .disposed(by: self.disposeBag)
        self.viewModel.pause
            .asObservable()
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] pause in
                var image = UIImage(asset: Asset.pauseCall)
                if pause {
                    image = UIImage(asset: Asset.unpauseCall)
                }
                self?.togglePause.setBackgroundImage(image, for: .normal)
            })
            .disposed(by: self.disposeBag)
        self.viewModel.audioMuted
            .asObservable()
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] muted in
                var image = UIImage(asset: Asset.audioOn)
                if muted {
                    image = UIImage(asset: Asset.audioOff)
                }
                self?.muteAudio.setBackgroundImage(image, for: .normal)
            })
            .disposed(by: self.disposeBag)

        self.viewModel.hasVideo
            .asObservable()
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] hasVideo in
                self?.muteAudio.isHidden = !hasVideo
            })
            .disposed(by: self.disposeBag)
        self.muteAudio.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.viewModel.muteAudio()
            })
            .disposed(by: self.disposeBag)
        self.togglePause.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.viewModel.toglePause()
            })
            .disposed(by: self.disposeBag)
    }

    func durationString(microcec: Float) -> String {
        if microcec == 0 {
            return ""
        }
        let durationInSec = Int(microcec / 1000000)
        let seconds = durationInSec % 60
        let minutes = (durationInSec / 60) % 60
        let hours = (durationInSec / 3600)
        switch hours {
        case 0:
            return String(format: "%02d:%02d", minutes, seconds)
        default:
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
    }
}
