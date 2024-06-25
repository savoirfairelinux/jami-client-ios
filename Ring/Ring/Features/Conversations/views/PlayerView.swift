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

import Reusable
import RxSwift
import UIKit

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
    let SLIDEBARLEADINGCONSTRAINT: CGFloat = 50
    let MAXSIZE: CGFloat = 60
    let MINSIZE: CGFloat = 40

    var withControls: Bool = true {
        didSet {
            togglePause.isHidden = !withControls
            muteAudio.isHidden = !withControls
            progressSlider.isHidden = !withControls
            durationLabel.isHidden = !withControls
        }
    }

    @IBOutlet var containerView: UIView!
    @IBOutlet var incomingVideo: UIView!
    @IBOutlet var togglePause: UIButton!
    @IBOutlet var muteAudio: UIButton!
    @IBOutlet var progressSlider: UISlider!
    @IBOutlet var durationLabel: UILabel!

    @IBOutlet var topGradient: UIView!
    @IBOutlet var bottomGradient: UIView!

    @IBOutlet var backgroundView: UIView!

    @IBOutlet var topConstraint: NSLayoutConstraint!
    @IBOutlet var bottomConstraint: NSLayoutConstraint!
    @IBOutlet var trailingConstraint: NSLayoutConstraint!
    @IBOutlet var leadingConstraint: NSLayoutConstraint!
    @IBOutlet var buttonsAllignmentConstraint: NSLayoutConstraint!
    @IBOutlet var progressSliderLeadingConstraint: NSLayoutConstraint!
    @IBOutlet var bottomGradientViewHeight: NSLayoutConstraint!
    @IBOutlet var topGradientViewHeight: NSLayoutConstraint!
    @IBOutlet var playButtonCenterY: NSLayoutConstraint!
    @IBOutlet var playButtonCenterX: NSLayoutConstraint!

    @IBOutlet var toglePauseWidthConstraint: NSLayoutConstraint!
    @IBOutlet var toglePauseHeightConstraint: NSLayoutConstraint!

    @IBOutlet var muteAudioWidthConstraint: NSLayoutConstraint!
    @IBOutlet var muteAudioHeightConstraint: NSLayoutConstraint!

    @IBOutlet var imageLeadingConstraint: NSLayoutConstraint!
    @IBOutlet var imageTrailingConstraint: NSLayoutConstraint!
    @IBOutlet var imageTopConstraint: NSLayoutConstraint!
    @IBOutlet var imageBottomConstraint: NSLayoutConstraint!

    var viewModel: PlayerViewModel!
    var incomingVideoLayer: AVSampleBufferDisplayLayer = .init()
    let disposeBag = DisposeBag()
    var sliderDisposeBag = DisposeBag()

    var sizeMode: PlayerMode = .inConversationMessage {
        didSet {
            sizeChanged()
        }
    }

    @IBAction func startSeekFrame(_: Any) {
        sliderDisposeBag = DisposeBag()
        viewModel.userStartSeeking()
        progressSlider.rx.value
            .subscribe(onNext: { [weak self] value in
                self?.viewModel.seekTimeVariable.accept(Float(value))
            })
            .disposed(by: sliderDisposeBag)
    }

    @IBAction func stopSeekFrame(_: UISlider) {
        sliderDisposeBag = DisposeBag()
        viewModel.userStopSeeking()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }

    func commonInit() {
        Bundle.main.loadNibNamed("PlayerView", owner: self, options: nil)
        addSubview(containerView)
        containerView.frame = bounds
        let circleImage = makeCircleWith(size: CGSize(width: 15, height: 15),
                                         backgroundColor: UIColor.white)
        progressSlider.setThumbImage(circleImage, for: .normal)
        progressSlider.setThumbImage(circleImage, for: .highlighted)
    }

    func frameUpdated() {
        if containerView.frame != bounds {
            containerView.frame = bounds
            containerView.setNeedsDisplay()
            updateLayerSize()
        }
    }

    func updateLayerSize() {
        if incomingVideoLayer.frame != containerView.bounds {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            incomingVideoLayer.frame = containerView.bounds
            CATransaction.commit()
        }
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
        if viewModel == nil { return }
        bindViews()
        viewModel.createPlayer()
    }

    func bindViews() {
        incomingVideo.layer.addSublayer(incomingVideoLayer)
        incomingVideoLayer.isOpaque = true
        incomingVideoLayer.videoGravity = .resizeAspect
        viewModel.playBackFrame
            .subscribe(onNext: { [weak self] buffer in
                guard let self = self else { return }
                if let buffer = buffer {
                    DispatchQueue.main.async {
                        self.updateLayerSize()
                        self.incomingVideoLayer.enqueue(buffer)
                    }
                }
            })
            .disposed(by: disposeBag)
        viewModel.playerPosition
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] position in
                self?.progressSlider.value = position
            })
            .disposed(by: disposeBag)
        viewModel.playerDuration
            .asObservable()
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] duration in
                let durationString = self?.durationString(microcec: duration) ?? ""
                self?.durationLabel.text = durationString
            })
            .disposed(by: disposeBag)
        viewModel.pause
            .asObservable()
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] pause in
                var image = UIImage(systemName: "pause.fill")
                if pause {
                    image = UIImage(systemName: "play.fill")
                }
                self?.togglePause.setImage(image, for: .normal)
            })
            .disposed(by: disposeBag)

        viewModel.audioMuted
            .asObservable()
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] muted in
                var image = UIImage(asset: Asset.audioOn)
                if muted {
                    image = UIImage(asset: Asset.audioOff)
                }
                self?.muteAudio.setImage(image, for: .normal)
            })
            .disposed(by: disposeBag)

        viewModel.hasVideo
            .asObservable()
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] hasVideo in
                guard let self = self else { return }
                self.muteAudio.isHidden = !hasVideo || !self.withControls
                self.backgroundView.backgroundColor = hasVideo ? UIColor.placeholderText : UIColor
                    .secondarySystemBackground
                self.incomingVideo.backgroundColor = hasVideo ? UIColor.black : UIColor
                    .secondarySystemBackground
                let color = hasVideo ? UIColor
                    .white : (UIColor.label.lighten(by: 50) ?? UIColor.label)
                self.togglePause.tintColor = color
                self.durationLabel.textColor = color
                self.progressSlider.minimumTrackTintColor = color
                self.progressSlider.maximumTrackTintColor = color
                self.progressSlider.thumbTintColor = color
                let size = self.sizeMode == .fullScreen ? 15 : 10
                let circleImage = self.makeCircleWith(size: CGSize(width: size, height: size),
                                                      backgroundColor: color)
                self.progressSlider.setThumbImage(circleImage, for: .normal)
                self.progressSlider.setThumbImage(circleImage, for: .highlighted)
            })
            .disposed(by: disposeBag)
        muteAudio.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.viewModel.muteAudio()
            })
            .disposed(by: disposeBag)
        togglePause.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.viewModel.toglePause()
            })
            .disposed(by: disposeBag)
    }

    func durationString(microcec: Float) -> String {
        if microcec == 0 {
            return ""
        }
        let durationInSec = Int(microcec / 1_000_000)
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
        switch sizeMode {
        case .fullScreen:
            backgroundView.backgroundColor = UIColor.black
            let circleImage = makeCircleWith(size: CGSize(width: 15, height: 15),
                                             backgroundColor: UIColor.white)
            progressSlider.setThumbImage(circleImage, for: .normal)
            progressSlider.setThumbImage(circleImage, for: .highlighted)
            let topAjust: CGFloat = UIDevice.current.hasNotch ? 10 : -8
            topConstraint.constant = MAXCONSTRAINT + topAjust
            bottomConstraint.constant = MAXCONSTRAINT
            trailingConstraint.constant = MAXCONSTRAINT
            leadingConstraint.constant = MAXCONSTRAINT - 8
            progressSliderLeadingConstraint.constant = MAXCONSTRAINT
            toglePauseWidthConstraint.constant = MAXSIZE
            toglePauseHeightConstraint.constant = MAXSIZE
            muteAudioWidthConstraint.constant = MAXSIZE
            muteAudioHeightConstraint.constant = MAXSIZE
            bottomGradientViewHeight.constant = MAXBOTTOMGRADIENTSIZE
            topGradientViewHeight.constant = MAXTOPGRADIENTSIZE
            playButtonCenterY.constant = PLAYBUTTONBOTTOMCONSTRAINT
            playButtonCenterX.priority = UILayoutPriority(rawValue: 999)
            buttonsAllignmentConstraint.priority = UILayoutPriority(rawValue: 250)
            topGradient.applyGradient(
                with: [UIColor(red: 0, green: 0, blue: 0, alpha: 1), UIColor(
                    red: 0,
                    green: 0,
                    blue: 0,
                    alpha: 0
                )],
                gradient: .vertical
            )
            bottomGradient.applyGradient(
                with: [UIColor(red: 0, green: 0, blue: 0, alpha: 0), UIColor(
                    red: 0,
                    green: 0,
                    blue: 0,
                    alpha: 1
                )],
                gradient: .vertical
            )
            topGradient.layoutIfNeeded()
            bottomGradient.layoutIfNeeded()
            bottomGradient.updateGradientFrame()
            topGradient.updateGradientFrame()
        case .inConversationMessage:
            let circleImage = makeCircleWith(size: CGSize(width: 10, height: 10),
                                             backgroundColor: UIColor.white)
            progressSlider.setThumbImage(circleImage, for: .normal)
            progressSlider.setThumbImage(circleImage, for: .highlighted)
            backgroundView.backgroundColor = UIColor.placeholderText
            bottomGradientViewHeight.constant = MINBOTTOMGRADIENTSIZE
            topGradientViewHeight.constant = MINTOPGRADIENTSIZE
            topConstraint.constant = MINCONSTRAINT
            bottomConstraint.constant = MINCONSTRAINT
            trailingConstraint.constant = MINCONSTRAINT
            leadingConstraint.constant = MINCONSTRAINT
            progressSliderLeadingConstraint.constant = SLIDEBARLEADINGCONSTRAINT
            toglePauseWidthConstraint.constant = MINSIZE
            toglePauseHeightConstraint.constant = MINSIZE
            muteAudioWidthConstraint.constant = MINSIZE
            muteAudioHeightConstraint.constant = MINSIZE
            playButtonCenterY.constant = 1
            playButtonCenterX.priority = UILayoutPriority(rawValue: 250)
            buttonsAllignmentConstraint.priority = UILayoutPriority(rawValue: 999)
            topGradient.applyGradient(
                with: [UIColor(red: 0, green: 0, blue: 0, alpha: 0.2), UIColor(
                    red: 0,
                    green: 0,
                    blue: 0,
                    alpha: 0
                )],
                gradient: .vertical
            )
            bottomGradient.applyGradient(
                with: [UIColor(red: 0, green: 0, blue: 0, alpha: 0), UIColor(
                    red: 0,
                    green: 0,
                    blue: 0,
                    alpha: 0.2
                )],
                gradient: .vertical
            )
            topGradient.layoutIfNeeded()
            bottomGradient.layoutIfNeeded()
            bottomGradient.updateGradientFrame()
            topGradient.updateGradientFrame()
        }
    }

    func changeControlsVisibility() {
        let alpha = bottomGradient.alpha == 0 ? 1 : 0
        UIView.animate(withDuration: 0.5, animations: { [weak self] in
            guard let self = self else { return }
            self.bottomGradient.alpha = CGFloat(alpha)
            self.topGradient.alpha = CGFloat(alpha)
        })
    }

    func resizeFrom(frame: CGRect) {
        let leftConstraint: CGFloat = frame.origin.x
        let topConstraint: CGFloat = frame.origin.y
        let rightConstraint: CGFloat = self.frame.width - frame.origin.x - frame.size.width
        let bottomConstraint: CGFloat = self.frame.height - frame.origin.y - frame.size.height
        imageLeadingConstraint.constant = leftConstraint
        imageTrailingConstraint.constant = rightConstraint
        imageTopConstraint.constant = topConstraint
        imageBottomConstraint.constant = bottomConstraint
        bottomGradient.alpha = 0
        topGradient.alpha = 0
        backgroundView.alpha = 0
        layoutIfNeeded()
        UIView.animate(withDuration: 0.2,
                       delay: 0.0,
                       options: [.curveEaseInOut],
                       animations: { [weak self] in
                        guard let self = self else { return }
                        self.imageLeadingConstraint.constant = 0
                        self.imageTrailingConstraint.constant = 0
                        self.imageTopConstraint.constant = 0
                        self.imageBottomConstraint.constant = 0
                        self.bottomGradient.alpha = 1
                        self.topGradient.alpha = 1
                        self.backgroundView.alpha = 1
                        self.layoutIfNeeded()
                       }, completion: nil)
    }
}
