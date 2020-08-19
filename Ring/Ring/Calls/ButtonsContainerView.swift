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

class ButtonsContainerView: UIView, NibLoadable {

    //Outlets
    @IBOutlet var containerView: UIView!
    @IBOutlet  weak var container: UIView!
    @IBOutlet weak var stackView: UIStackView!
    @IBOutlet weak var backgroundBlurEffect: UIVisualEffectView!
    @IBOutlet  weak var muteAudioButton: UIButton!
    @IBOutlet  weak var muteVideoButton: UIButton!
    @IBOutlet  weak var pauseCallButton: UIButton!
    @IBOutlet  weak var dialpadButton: UIButton!
    @IBOutlet  weak var switchSpeakerButton: UIButton!
    @IBOutlet  weak var cancelButton: UIButton!
    @IBOutlet  weak var switchCameraButton: UIButton!
    @IBOutlet  weak var acceptCallButton: UIButton!

    //Constraints
    @IBOutlet weak var cancelButtonWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var cancelButtonCenterConstraint: NSLayoutConstraint!
    @IBOutlet weak var cancelButtonBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var cancelButtonHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var stackViewYConstraint: NSLayoutConstraint!
    @IBOutlet weak var stackViewWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var containerHeightConstraint: NSLayoutConstraint!

    let disposeBag = DisposeBag()
    var isCallStarted: Bool = false

    var viewModel: ButtonsContainerViewModel? {
        didSet {
            self.viewModel?.observableCallOptions
                .observeOn(MainScheduler.instance)
                .subscribe(onNext: { [weak self] callOptions in
                    switch callOptions {
                    case .none:
                        self?.withoutOptions()
                    case .optionsWithoutSpeakerphone:
                        self?.optionsWithoutSpeaker()
                    case .optionsWithSpeakerphone:
                        self?.optionsWithSpeaker()
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
    }

    func commonInit() {
        Bundle.main.loadNibNamed("ButtonsContainerView", owner: self, options: nil)
        addSubview(containerView)
        containerView.frame = self.bounds
        self.container.clipsToBounds = false
    }

    func withoutOptions() {
        self.container.backgroundColor = UIColor.clear
        self.backgroundBlurEffect.isHidden = true
        switchCameraButton.isHidden = true
        muteAudioButton.isHidden = true
        muteVideoButton.isHidden = true
        pauseCallButton.isHidden = true
        dialpadButton.isHidden = true
        switchSpeakerButton.isHidden = true
        cancelButton.isHidden = false
        if self.viewModel?.isIncoming ?? false {
            acceptCallButton.isHidden = false
            cancelButtonBottomConstraint.constant = 60
            cancelButtonCenterConstraint.constant = -80
            return
        }
        cancelButtonCenterConstraint.constant = 0
        cancelButtonBottomConstraint.constant = 20
    }

    func optionsWithSpeaker() {
        acceptCallButton.isHidden = true
        cancelButtonCenterConstraint.constant = 0
        self.backgroundBlurEffect.isHidden = false
        muteAudioButton.isHidden = false
        if self.viewModel?.isAudioOnly ?? false {
            muteVideoButton.isHidden = true
            switchCameraButton.isHidden = true
            if self.viewModel?.isSipCall ?? false {
                dialpadButton.isHidden = false
            }
            cancelButtonBottomConstraint.constant = 20
        } else {
            muteVideoButton.isHidden = false
            switchCameraButton.isHidden = false
            cancelButtonBottomConstraint.constant = 80
        }
        pauseCallButton.isHidden = false
        switchSpeakerButton.isEnabled = true
        switchSpeakerButton.isHidden = false
        cancelButton.isHidden = false
        setUpConference()
        setButtonsColor()
    }

    func optionsWithoutSpeaker() {
        acceptCallButton.isHidden = true
        cancelButtonCenterConstraint.constant = 0
        if self.viewModel?.isAudioOnly ?? false {
            muteVideoButton.isHidden = true
            switchCameraButton.isHidden = true
            if self.viewModel?.isSipCall ?? false {
                dialpadButton.isHidden = false
            }
            cancelButtonBottomConstraint.constant = 20
        } else {
            switchCameraButton.isHidden = false
            muteVideoButton.isHidden = false
            cancelButtonBottomConstraint.constant = 80
        }
        switchSpeakerButton.isEnabled = false
        self.muteAudioButton.isHidden = false
        switchSpeakerButton.isHidden = false
        self.backgroundBlurEffect.isHidden = false
        pauseCallButton.isHidden = false
        cancelButton.isHidden = false
        setUpConference()
        setButtonsColor()
    }

    func setUpConference() {
        if !(self.viewModel?.isConference ?? false) {
            return
        }
        pauseCallButton.isHidden = true
        muteAudioButton.isHidden = true
        muteVideoButton.isHidden = true
        cancelButtonBottomConstraint.constant = 0
    }

    func updateView() {
        if switchSpeakerButton.isEnabled && !switchSpeakerButton.isHidden {
            self.optionsWithSpeaker()
        } else if !switchSpeakerButton.isHidden {
            self.optionsWithoutSpeaker()
        }
    }

    func setButtonsColor() {
        if self.viewModel?.isAudioOnly ?? false {
            pauseCallButton.tintColor = UIColor.gray
            pauseCallButton.borderColor = UIColor.gray
            muteAudioButton.tintColor = UIColor.gray
            muteAudioButton.borderColor = UIColor.gray
            dialpadButton.tintColor = UIColor.gray
            dialpadButton.borderColor = UIColor.gray
            switchSpeakerButton.tintColor = UIColor.gray
            switchSpeakerButton.borderColor = UIColor.gray
            return
        }
        pauseCallButton.tintColor = UIColor.white
        pauseCallButton.borderColor = UIColor.white
        muteAudioButton.tintColor = UIColor.white
        muteAudioButton.borderColor = UIColor.white
        dialpadButton.tintColor = UIColor.white
        dialpadButton.borderColor = UIColor.white
        switchSpeakerButton.tintColor = UIColor.white
        switchSpeakerButton.borderColor = UIColor.white
        muteVideoButton.tintColor = UIColor.white
        muteVideoButton.borderColor = UIColor.white
        switchCameraButton.tintColor = UIColor.white
    }
}
