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

enum PlayerMode {
    case fullScreen
    case inConversationMessage
}

class PlayerView: UIView {

    let MAXCONSTRAINT: CGFloat = 30
    let MINCONSTRAINT: CGFloat = 10
    let MAXTOPGRADIENTSIZE: CGFloat = 100
    let MINTOPGRADIENTSIZE: CGFloat = 50
    let MAXBOTTOMGRADIENTSIZE: CGFloat = 160
    let MINBOTTOMGRADIENTSIZE: CGFloat = 80
    let PLAYBUTTONBOTTOMCONSTRAINT: CGFloat = 55
    let SLIDEBARLEADINGCONSTRAINT: CGFloat = 55
    let MAXSIZE: CGFloat = 40
    let MINSIZE: CGFloat = 30

    @IBOutlet var containerView: UIView!
    @IBOutlet weak var incomingImage: UIImageView!
    @IBOutlet weak var togglePause: UIButton!
    @IBOutlet weak var muteAudio: UIButton!
    @IBOutlet weak var progressSlider: UISlider!
    @IBOutlet weak var durationLabel: UILabel!

    @IBOutlet weak var topGradient: UIView!
    @IBOutlet weak var bottomGradient: UIView!

    @IBOutlet weak var backgroundView: UIView!

    @IBOutlet weak var topConstraint: NSLayoutConstraint!
    @IBOutlet weak var bottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var trailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var leadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var buttonsAllignmentConstraint: NSLayoutConstraint!
    @IBOutlet weak var progressSliderLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var bottomGradientViewHeight: NSLayoutConstraint!
    @IBOutlet weak var topGradientViewHeight: NSLayoutConstraint!
    @IBOutlet weak var playButtonCenterY: NSLayoutConstraint!
    @IBOutlet weak var playButtonCenterX: NSLayoutConstraint!

    @IBOutlet weak var toglePauseWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var toglePauseHeightConstraint: NSLayoutConstraint!

    @IBOutlet weak var muteAudioWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var muteAudioHeightConstraint: NSLayoutConstraint!

    var viewModel: PlayerViewModel!
    let disposeBag = DisposeBag()
    var sliderDisposeBag = DisposeBag()

    var sizeMode: PlayerMode = .inConversationMessage {
        didSet {
            self.sizeChanged()
        }
    }

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

    func sizeChanged() {
        switch self.sizeMode {
        case .fullScreen:
            backgroundView.backgroundColor = UIColor.black
            let circleImage = makeCircleWith(size: CGSize(width: 20, height: 20),
                                             backgroundColor: UIColor.white)
            progressSlider.setThumbImage(circleImage, for: .normal)
            progressSlider.setThumbImage(circleImage, for: .highlighted)
            let topAjust: CGFloat = UIDevice.current.hasNotch ? 10 : -8
            topConstraint.constant = MAXCONSTRAINT + topAjust
            bottomConstraint.constant = MAXCONSTRAINT
            trailingConstraint.constant = MAXCONSTRAINT
            leadingConstraint.constant = MAXCONSTRAINT - 8
            progressSliderLeadingConstraint.constant = MAXCONSTRAINT
            toglePauseWidthConstraint.constant = MAXSIZE + 5
            toglePauseHeightConstraint.constant = MAXSIZE
            muteAudioWidthConstraint.constant = MAXSIZE
            muteAudioHeightConstraint.constant = MAXSIZE
            bottomGradientViewHeight.constant = MAXBOTTOMGRADIENTSIZE
            topGradientViewHeight.constant = MAXTOPGRADIENTSIZE
            playButtonCenterY.constant = PLAYBUTTONBOTTOMCONSTRAINT
            playButtonCenterX.priority = UILayoutPriority(rawValue: 999)
            buttonsAllignmentConstraint.priority = UILayoutPriority(rawValue: 250)
            self.topGradient.applyGradient(with: [UIColor(red: 0, green: 0, blue: 0, alpha: 1), UIColor(red: 0, green: 0, blue: 0, alpha: 0)], gradient: .vertical)
            self.bottomGradient.applyGradient(with: [UIColor(red: 0, green: 0, blue: 0, alpha: 0), UIColor(red: 0, green: 0, blue: 0, alpha: 1)], gradient: .vertical)
            self.topGradient.layoutIfNeeded()
            self.bottomGradient.layoutIfNeeded()
            self.bottomGradient.updateGradientFrame()
            self.topGradient.updateGradientFrame()
        case .inConversationMessage:
            let circleImage = makeCircleWith(size: CGSize(width: 15, height: 15),
                                             backgroundColor: UIColor.white)
            progressSlider.setThumbImage(circleImage, for: .normal)
            progressSlider.setThumbImage(circleImage, for: .highlighted)
            if #available(iOS 13.0, *) {
                backgroundView.backgroundColor = UIColor.placeholderText
            } else {
                backgroundView.backgroundColor = UIColor.lightGray
            }
            bottomGradientViewHeight.constant = MINBOTTOMGRADIENTSIZE
            topGradientViewHeight.constant = MINTOPGRADIENTSIZE
            topConstraint.constant = MINCONSTRAINT
            bottomConstraint.constant = MINCONSTRAINT
            trailingConstraint.constant = MINCONSTRAINT
            leadingConstraint.constant = MINCONSTRAINT
            progressSliderLeadingConstraint.constant = SLIDEBARLEADINGCONSTRAINT
            toglePauseWidthConstraint.constant = MINSIZE + 3
            toglePauseHeightConstraint.constant = MINSIZE
            muteAudioWidthConstraint.constant = MINSIZE
            muteAudioHeightConstraint.constant = MINSIZE
            playButtonCenterY.constant = 1
            playButtonCenterX.priority = UILayoutPriority(rawValue: 250)
            buttonsAllignmentConstraint.priority = UILayoutPriority(rawValue: 999)
            self.topGradient.applyGradient(with: [UIColor(red: 0, green: 0, blue: 0, alpha: 0.2), UIColor(red: 0, green: 0, blue: 0, alpha: 0)], gradient: .vertical)
            self.bottomGradient.applyGradient(with: [UIColor(red: 0, green: 0, blue: 0, alpha: 0), UIColor(red: 0, green: 0, blue: 0, alpha: 0.2)], gradient: .vertical)
            self.topGradient.layoutIfNeeded()
            self.bottomGradient.layoutIfNeeded()
            self.bottomGradient.updateGradientFrame()
            self.topGradient.updateGradientFrame()
        }
    }

    func changeControlsVisibility() {
        let alpha = bottomGradient.alpha == 0 ? 1 : 0
        UIView.animate(withDuration: 0.5, animations: {
            self.bottomGradient.alpha = CGFloat(alpha)
            self.topGradient.alpha = CGFloat(alpha)
        })
    }
}
