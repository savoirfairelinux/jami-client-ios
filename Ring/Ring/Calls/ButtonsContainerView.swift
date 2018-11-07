/*
 *  Copyright (C) 2017 Savoir-faire Linux Inc.
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

class ButtonsContainerView: UIView, NibLoadable {

    //Outlets
    @IBOutlet var containerView: UIView!
    @IBOutlet  weak var container: UIView!
    @IBOutlet weak var stackView: UIStackView!
    @IBOutlet weak var backgroundBlurEffect: UIVisualEffectView!
    @IBOutlet  weak var muteAudioButton: UIButton!
    @IBOutlet  weak var muteVideoButton: UIButton!
    @IBOutlet  weak var pauseCallButton: UIButton!
    @IBOutlet  weak var switchCameraButton: UIButton!
    @IBOutlet  weak var switchSpeakerButton: UIButton!
    @IBOutlet  weak var cancelButton: UIButton!

    //Constraints
    @IBOutlet weak var cancelButtonWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var cancelButtonHeightConstraint: NSLayoutConstraint!

    let disposeBag = DisposeBag()
    var isCallStarted: Bool = false

    var viewModel: ButtonsContainerViewModel? {
        didSet {
            self.viewModel?.observableCallOptions
                .observeOn(MainScheduler.instance)
                .subscribe(onNext: { (callOptions) in
                    switch callOptions {
                    case .none:
                        self.withoutOptions()
                    case .optionsWithoutSpeakerphone:
                        self.optionsWithoutSpeaker()
                    case .optionsWithSpeakerphone:
                        self.optionsWithSpeaker()
                    }
                }).disposed(by: self.disposeBag)
        }
    }
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.commonInit()
    }

    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)!
        self.commonInit()
    }

    override open func didMoveToWindow() {
        super.didMoveToWindow()
        self.cancelButton.backgroundColor = UIColor.red
        if #available(iOS 11.0, *) {
            guard let window = self.window else {
                return
            }
        }
    }

    func commonInit() {
        Bundle.main.loadNibNamed("ButtonsContainerView", owner: self, options: nil)
        addSubview(containerView)
        containerView.frame = self.bounds
    }

    func withoutOptions() {
            self.container.backgroundColor = UIColor.clear
            self.backgroundBlurEffect.isHidden = true
            muteAudioButton.isHidden = true
            muteVideoButton.isHidden = true
            pauseCallButton.isHidden = true
            switchCameraButton.isHidden = true
            switchSpeakerButton.isHidden = true
            cancelButton.isHidden = false
    }

    func optionsWithSpeaker() {
        if !self.isCallStarted {
            self.isCallStarted = true
            self.backgroundBlurEffect.isHidden = false
            muteAudioButton.isHidden = false
            if self.viewModel?.isAudioOnly ?? false {
                muteVideoButton.isHidden = true
                switchCameraButton.isHidden = true
            } else {
                muteVideoButton.isHidden = false
                switchCameraButton.isHidden = false
            }
            pauseCallButton.isHidden = false
            switchSpeakerButton.isHidden = false
            switchSpeakerButton.alpha = 1.00
            switchSpeakerButton.isEnabled = true
            cancelButton.isHidden = false
        }
    }

    func optionsWithoutSpeaker() {
        if !self.isCallStarted {
            self.isCallStarted = true
            if self.viewModel?.isAudioOnly ?? false {
                muteVideoButton.isHidden = true
                switchCameraButton.isHidden = true
                switchSpeakerButton.isHidden = true
            } else {
                muteVideoButton.isHidden = false
                switchCameraButton.isHidden = false
                switchSpeakerButton.isHidden = false
            }
            self.muteAudioButton.isHidden = false
            self.backgroundBlurEffect.isHidden = false
            pauseCallButton.isHidden = false
            cancelButton.isHidden = false
        }
    }
}
