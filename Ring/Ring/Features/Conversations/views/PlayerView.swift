/*
 * Copyright (C) 2020-2025 Savoir-faire Linux Inc.
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
    @IBOutlet weak var incomingVideo: UIView!
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

    @IBOutlet weak var togglePauseWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var togglePauseHeightConstraint: NSLayoutConstraint!

    @IBOutlet weak var muteAudioWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var muteAudioHeightConstraint: NSLayoutConstraint!

    @IBOutlet weak var imageLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var imageTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var imageTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var imageBottomConstraint: NSLayoutConstraint!

    var viewModel: PlayerViewModel!
    var incomingVideoLayer: AVSampleBufferDisplayLayer = AVSampleBufferDisplayLayer()
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
                self?.viewModel.seekTimeVariable.accept(Float(value))
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

    func frameUpdated() {
        if containerView.frame != self.bounds {
            containerView.frame = self.bounds
            containerView.setNeedsDisplay()
            updateLayerSize()
        }
    }

    func updateLayerSize() {
        if self.incomingVideoLayer.frame != self.containerView.bounds {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            self.incomingVideoLayer.frame = self.containerView.bounds
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
        if self.viewModel == nil { return }
        bindViews()
        viewModel.createPlayer()
    }

    func bindViews() {
        self.incomingVideo.layer.addSublayer(self.incomingVideoLayer)
        self.incomingVideoLayer.isOpaque = true
        self.incomingVideoLayer.videoGravity = .resizeAspect
        self.viewModel.playBackFrame
            .subscribe(onNext: { [weak self] buffer in
                guard let self = self else { return }
                if let buffer = buffer {
                    DispatchQueue.main.async {
                        self.updateLayerSize()
                        self.incomingVideoLayer.enqueue(buffer)
                    }
                }
            })
            .disposed(by: self.disposeBag)
        self.viewModel.playerPosition
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] position in
                self?.progressSlider.value = position
            })
            .disposed(by: self.disposeBag)
        self.viewModel.playerDuration
            .asObservable()
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] duration in
                let durationString = self?.durationString(microcec: duration) ?? ""
                self?.durationLabel.text = durationString
            })
            .disposed(by: self.disposeBag)
        self.viewModel.pause
            .asObservable()
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] pause in
                var image = UIImage(systemName: "pause.fill")
                if pause {
                    image = UIImage(systemName: "play.fill")
                }
                self?.togglePause.setImage(image, for: .normal)
            })
            .disposed(by: self.disposeBag)

        self.viewModel.audioMuted
            .asObservable()
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] muted in
                var image = UIImage(asset: Asset.audioOn)
                if muted {
                    image = UIImage(asset: Asset.audioOff)
                }
                self?.muteAudio.setImage(image, for: .normal)
            })
            .disposed(by: self.disposeBag)

        self.viewModel.hasVideo
            .asObservable()
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] hasVideo in
                guard let self = self else { return }
                self.muteAudio.isHidden = !hasVideo || !self.withControls
                self.backgroundView.backgroundColor = hasVideo ? UIColor.placeholderText : UIColor.secondarySystemBackground
                self.incomingVideo.backgroundColor = hasVideo ? UIColor.black : UIColor.secondarySystemBackground
                let color = hasVideo ? UIColor.white : (UIColor.label.lighten(by: 50) ?? UIColor.label)
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
            .disposed(by: self.disposeBag)
        self.muteAudio.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.viewModel.muteAudio()
            })
            .disposed(by: self.disposeBag)
        self.togglePause.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.viewModel.togglePause()
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
            self.backgroundView.backgroundColor = UIColor.black
            let circleImage = makeCircleWith(size: CGSize(width: 15, height: 15),
                                             backgroundColor: UIColor.white)
            self.progressSlider.setThumbImage(circleImage, for: .normal)
            self.progressSlider.setThumbImage(circleImage, for: .highlighted)
            let topAjust: CGFloat = UIDevice.current.hasNotch ? 10 : -8
            self.topConstraint.constant = MAXCONSTRAINT + topAjust
            self.bottomConstraint.constant = MAXCONSTRAINT
            self.trailingConstraint.constant = MAXCONSTRAINT
            self.leadingConstraint.constant = MAXCONSTRAINT - 8
            self.progressSliderLeadingConstraint.constant = MAXCONSTRAINT
            self.togglePauseWidthConstraint.constant = MAXSIZE
            self.togglePauseHeightConstraint.constant = MAXSIZE
            self.muteAudioWidthConstraint.constant = MAXSIZE
            self.muteAudioHeightConstraint.constant = MAXSIZE
            self.bottomGradientViewHeight.constant = MAXBOTTOMGRADIENTSIZE
            self.topGradientViewHeight.constant = MAXTOPGRADIENTSIZE
            self.playButtonCenterY.constant = PLAYBUTTONBOTTOMCONSTRAINT
            self.playButtonCenterX.priority = UILayoutPriority(rawValue: 999)
            self.buttonsAllignmentConstraint.priority = UILayoutPriority(rawValue: 250)
            self.topGradient.applyGradient(with: [UIColor(red: 0, green: 0, blue: 0, alpha: 1), UIColor(red: 0, green: 0, blue: 0, alpha: 0)], gradient: .vertical)
            self.bottomGradient.applyGradient(with: [UIColor(red: 0, green: 0, blue: 0, alpha: 0), UIColor(red: 0, green: 0, blue: 0, alpha: 1)], gradient: .vertical)
            self.topGradient.layoutIfNeeded()
            self.bottomGradient.layoutIfNeeded()
            self.bottomGradient.updateGradientFrame()
            self.topGradient.updateGradientFrame()
        case .inConversationMessage:
            let circleImage = makeCircleWith(size: CGSize(width: 10, height: 10),
                                             backgroundColor: UIColor.white)
            self.progressSlider.setThumbImage(circleImage, for: .normal)
            self.progressSlider.setThumbImage(circleImage, for: .highlighted)
            self.backgroundView.backgroundColor = UIColor.placeholderText
            self.bottomGradientViewHeight.constant = MINBOTTOMGRADIENTSIZE
            self.topGradientViewHeight.constant = MINTOPGRADIENTSIZE
            self.topConstraint.constant = MINCONSTRAINT
            self.bottomConstraint.constant = MINCONSTRAINT
            self.trailingConstraint.constant = MINCONSTRAINT
            self.leadingConstraint.constant = MINCONSTRAINT
            self.progressSliderLeadingConstraint.constant = SLIDEBARLEADINGCONSTRAINT
            self.togglePauseWidthConstraint.constant = MINSIZE
            self.togglePauseHeightConstraint.constant = MINSIZE
            self.muteAudioWidthConstraint.constant = MINSIZE
            self.muteAudioHeightConstraint.constant = MINSIZE
            self.playButtonCenterY.constant = 1
            self.playButtonCenterX.priority = UILayoutPriority(rawValue: 250)
            self.buttonsAllignmentConstraint.priority = UILayoutPriority(rawValue: 999)
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
        self.imageLeadingConstraint.constant = leftConstraint
        self.imageTrailingConstraint.constant = rightConstraint
        self.imageTopConstraint.constant = topConstraint
        self.imageBottomConstraint.constant = bottomConstraint
        self.bottomGradient.alpha = 0
        self.topGradient.alpha = 0
        self.backgroundView.alpha = 0
        self.layoutIfNeeded()
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
