/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
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
import UIKit
import Reusable
import RxSwift

class ButtonsContainerView: UIView, NibLoadable, UIScrollViewDelegate {

    // Outlets
    @IBOutlet var containerView: UIView!
    @IBOutlet  weak var container: UIView!
    @IBOutlet weak var stackView: UIStackView!
    @IBOutlet weak var firstPageStackView: UIStackView!
    @IBOutlet weak var secondPageStackView: UIStackView!
    @IBOutlet weak var backgroundBlurEffect: UIVisualEffectView!
    @IBOutlet  weak var cancelButton: UIButton! // cancel pending outgoing call
    @IBOutlet  weak var pageControl: UIPageControl!
    @IBOutlet  weak var scrollView: UIScrollView!

    // Constraints
    @IBOutlet weak var cancelButtonWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var cancelButtonHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var cancelButtonBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var containerHeightConstraint: NSLayoutConstraint!

    // Buttons
    var muteAudioButton: UIButton!
    var muteVideoButton: UIButton!
    var pauseCallButton: UIButton!
    var dialpadButton: UIButton!
    var stopButton: UIButton! // stop current call
    var switchCameraButton: UIButton!
    var switchSpeakerButton: UIButton!
    var addParticipantButton: UIButton!
    var raiseHandButton: UIButton!

    private let disposeBag = DisposeBag()
    var callViewMode: CallViewMode = .audio

    var viewModel: ButtonsContainerViewModel? {
        didSet {
            self.viewModel?.observableCallOptions
                .observe(on: MainScheduler.instance)
                .subscribe(onNext: { [weak self] callOptions in
                    switch callOptions {
                    case .none:
                        self?.withoutOptions()
                    case .optionsWithoutSpeakerphone:
                        self?.update(withSpeakerShow: true)
                    case .optionsWithSpeakerphone:
                        self?.update(withSpeakerShow: false)
                    }
                })
                .disposed(by: self.disposeBag)
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.commonInit()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.commonInit()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        self.cancelButton.backgroundColor = UIColor.red
        self.stopButton.backgroundColor = UIColor.red
    }

    func commonInit() {
        Bundle.main.loadNibNamed("ButtonsContainerView", owner: self, options: nil)
        addSubview(containerView)
        containerView.frame = self.bounds
        self.container.clipsToBounds = false
        scrollView.delegate = self
        muteAudioButton = configureButton(image: UIImage(asset: Asset.audioMuted))
        muteVideoButton = configureButton(image: UIImage(asset: Asset.videoMuted))
        pauseCallButton = configureButton(image: UIImage(asset: Asset.pauseCall))
        dialpadButton = configureButton(image: UIImage(asset: Asset.dialpad))
        stopButton = configureButton(image: UIImage(asset: Asset.stopCall))
        stopButton.borderColor = UIColor.red
        switchCameraButton = configureButton(image: UIImage(asset: Asset.switchCamera))
        switchSpeakerButton = configureButton(image: UIImage(asset: Asset.enableSpeakerphone))
        addParticipantButton = configureButton(image: UIImage(asset: Asset.addPerson))
        raiseHandButton = configureButton(image: UIImage(asset: Asset.raiseHand)?.withRenderingMode(.alwaysTemplate))
        pageControl.addTarget(self, action: #selector(changePage), for: UIControl.Event.valueChanged)
    }

    func configureButton(image: UIImage?) -> UIButton {
        let button = UIButton()
        button.heightAnchor.constraint(equalToConstant: 50).isActive = true
        button.widthAnchor.constraint(equalToConstant: 50).isActive = true
        button.cornerRadius = 25
        button.borderWidth = 1
        button.borderColor = UIColor.white
        button.tintColor = UIColor.white
        button.setImage(image, for: .normal)
        return button
    }

    func withoutOptions() {
        self.container.backgroundColor = UIColor.clear
        self.backgroundBlurEffect.isHidden = true
        cancelButton.isHidden = false
        firstPageStackView.removeSubviews()
        secondPageStackView.removeSubviews()
        pageControl.isHidden = true
        if self.viewModel?.isIncoming ?? false {
            cancelButtonBottomConstraint.constant = 60
            return
        }
        cancelButtonBottomConstraint.constant = 20
        scrollView.isScrollEnabled = false
    }

    func update(withSpeakerShow status: Bool) {
        self.backgroundBlurEffect.isHidden = false
        cancelButton.isHidden = true
        // Hide speaker button when speaker is disabled
        switchSpeakerButton.isHidden = status
        let isSip = self.viewModel?.isSipCall ?? false
        let isConference = self.viewModel?.isConference ?? false
        let audioOnly = self.callViewMode == .audio
        var havePages = false
        if isSip {
            firstPageStackView.removeSubviews()
            secondPageStackView.removeSubviews()
            firstPageStackView.addArrangedSubview(stopButton)
            firstPageStackView.addArrangedSubview(pauseCallButton)
            firstPageStackView.addArrangedSubview(muteAudioButton)
            firstPageStackView.addArrangedSubview(switchSpeakerButton)
            firstPageStackView.addArrangedSubview(dialpadButton)
        } else if audioOnly {
            let screenRect = UIScreen.main.bounds
            let screenWidth: CGFloat = screenRect.size.width
            let buttonsWidth: CGFloat = 7 * 50 + 30 * 6
            havePages = screenWidth < buttonsWidth
            firstPageStackView.removeSubviews()
            secondPageStackView.removeSubviews()
            firstPageStackView.addArrangedSubview(stopButton)
            firstPageStackView.addArrangedSubview(pauseCallButton)
            firstPageStackView.addArrangedSubview(switchSpeakerButton)
            firstPageStackView.addArrangedSubview(addParticipantButton)
            if havePages {
                secondPageStackView.addArrangedSubview(muteAudioButton)
                secondPageStackView.addArrangedSubview(muteVideoButton)
                if isConference {
                    secondPageStackView.addArrangedSubview(raiseHandButton)
                }
            } else {
                firstPageStackView.addArrangedSubview(muteAudioButton)
                firstPageStackView.addArrangedSubview(muteVideoButton)
                if isConference {
                    firstPageStackView.addArrangedSubview(raiseHandButton)
                }
            }
        } else {
            let screenRect = UIScreen.main.bounds
            let screenWidth: CGFloat = screenRect.size.width
            let buttonsWidth: CGFloat = 8 * 50 + 30 * 7 // 540
            havePages = screenWidth < buttonsWidth
            firstPageStackView.removeSubviews()
            secondPageStackView.removeSubviews()
            firstPageStackView.addArrangedSubview(stopButton)
            firstPageStackView.addArrangedSubview(pauseCallButton)
            firstPageStackView.addArrangedSubview(switchCameraButton)
            firstPageStackView.addArrangedSubview(switchSpeakerButton)
            firstPageStackView.addArrangedSubview(addParticipantButton)
            if havePages {
                secondPageStackView.addArrangedSubview(muteAudioButton)
                secondPageStackView.addArrangedSubview(muteVideoButton)
                if isConference {
                    secondPageStackView.addArrangedSubview(raiseHandButton)
                }
            } else {
                firstPageStackView.addArrangedSubview(muteAudioButton)
                firstPageStackView.addArrangedSubview(muteVideoButton)
                if isConference {
                    firstPageStackView.addArrangedSubview(raiseHandButton)
                }
            }
        }
        pageControl.isHidden = !havePages
        scrollView.isScrollEnabled = havePages
        if self.callViewMode == .audio {
            cancelButtonBottomConstraint.constant = 80
        } else {
            cancelButtonBottomConstraint.constant = 80
        }
        setButtonsColor()
    }

    func updateView() {
        if firstPageStackView.subviews.isEmpty {
            self.withoutOptions()
        } else if !switchSpeakerButton.isHidden {
            self.update(withSpeakerShow: false)
        }
    }

    func setButtonsColor() {
        if self.callViewMode == .audio {
            updateColorForAudio()
            return
        }
        updateColorForVideo()
    }

    func updateColorForAudio() {
        pageControl.currentPageIndicatorTintColor = UIColor.gray
        pauseCallButton.tintColor = UIColor.gray
        pauseCallButton.borderColor = UIColor.gray
        muteAudioButton.tintColor = UIColor.gray
        muteAudioButton.borderColor = UIColor.gray
        muteVideoButton.tintColor = UIColor.gray
        muteVideoButton.borderColor = UIColor.gray
        addParticipantButton.tintColor = UIColor.gray
        addParticipantButton.borderColor = UIColor.gray
        dialpadButton.tintColor = UIColor.gray
        dialpadButton.borderColor = UIColor.gray
        switchSpeakerButton.tintColor = UIColor.gray
        switchSpeakerButton.borderColor = UIColor.gray
        raiseHandButton.tintColor = UIColor.gray
    }

    func updateColorForVideo() {
        pageControl.currentPageIndicatorTintColor = UIColor.white
        pauseCallButton.tintColor = UIColor.white
        pauseCallButton.borderColor = UIColor.white
        muteAudioButton.tintColor = UIColor.white
        muteAudioButton.borderColor = UIColor.white
        addParticipantButton.tintColor = UIColor.white
        addParticipantButton.borderColor = UIColor.white
        dialpadButton.tintColor = UIColor.white
        dialpadButton.borderColor = UIColor.white
        switchSpeakerButton.tintColor = UIColor.white
        switchSpeakerButton.borderColor = UIColor.white
        muteVideoButton.tintColor = UIColor.white
        muteVideoButton.borderColor = UIColor.white
        switchCameraButton.tintColor = UIColor.white
        raiseHandButton.tintColor = UIColor.white
    }

    @objc
    func changePage(sender: AnyObject) {
        let xpoint = CGFloat(pageControl.currentPage) * scrollView.frame.size.width
        scrollView.setContentOffset(CGPoint(x: xpoint, y: 0), animated: true)
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        let pageNumber = round(scrollView.contentOffset.x / scrollView.frame.size.width)
        pageControl.currentPage = Int(pageNumber)
    }

}
