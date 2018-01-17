/*
 *  Copyright (C) 2017 Savoir-faire Linux Inc.
 *
 *  Author: Silbino Gonçalves Matado <silbino.gmatado@savoirfairelinux.com>
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
import Chameleon
import RxSwift
import Reusable
import SwiftyBeaver

class CallViewController: UIViewController, StoryboardBased, ViewModelBased {

    //preview screen
    @IBOutlet private weak var profileImageView: UIImageView!
    @IBOutlet private weak var nameLabel: UILabel!
    @IBOutlet private weak var durationLabel: UILabel!
    @IBOutlet private weak var infoBottomLabel: UILabel!

    @IBOutlet private weak var cancelButton: UIButton!
    @IBOutlet private weak var mainView: UIView!

    //video screen
    @IBOutlet private weak var callView: UIView!
    @IBOutlet private weak var incomingVideo: UIImageView!
    @IBOutlet private weak var capturedVideo: UIImageView!
    @IBOutlet private weak var infoContainer: UIView!
    @IBOutlet private weak var callProfileImage: UIImageView!
    @IBOutlet private weak var callNameLabel: UILabel!
    @IBOutlet private weak var callInfoTimerLabel: UILabel!
    @IBOutlet private weak var infoLabelConstraint: NSLayoutConstraint!

    // call options buttons
    @IBOutlet private weak var buttonsContainer: UIView!
    @IBOutlet private weak var muteAudioButton: UIButton!
    @IBOutlet private weak var muteVideoButton: UIButton!
    @IBOutlet private weak var pauseCallButton: UIButton!
    @IBOutlet private weak var switchCameraButton: UIButton!

    var viewModel: CallViewModel!

    fileprivate let disposeBag = DisposeBag()

    private let log = SwiftyBeaver.self

    private var task: DispatchWorkItem?

    override func viewDidLoad() {
        super.viewDidLoad()
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(screenTaped))
        self.mainView.addGestureRecognizer(tapGestureRecognizer)
        self.setupUI()
        self.setupBindings()
    }

    func setupUI() {
        self.cancelButton.backgroundColor = UIColor.red
        self.infoContainer.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        self.buttonsContainer.backgroundColor = UIColor.black.withAlphaComponent(0.3)
    }

    func setupBindings() {
        //bind actions
        self.cancelButton.rx.tap
            .subscribe(onNext: { [weak self] in
            self?.removeFromScreen()
            self?.viewModel.cancelCall()
        }).disposed(by: self.disposeBag)

        self.muteAudioButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.viewModel.muteAudio()
            }).disposed(by: self.disposeBag)

        self.muteVideoButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.viewModel.muteVideo()
            }).disposed(by: self.disposeBag)

        self.pauseCallButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.viewModel.pauseCall()
            }).disposed(by: self.disposeBag)

        self.switchCameraButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.viewModel.switchCamera()
            }).disposed(by: self.disposeBag)

        //Data bindings
        self.viewModel.contactImageData.asObservable()
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] dataOrNil in
            if let imageData = dataOrNil {
                if let image = UIImage(data: imageData) {
                    self?.profileImageView.image = image
                    self?.callProfileImage.image = image
                }
            }
        }).disposed(by: self.disposeBag)

        self.viewModel.dismisVC
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] dismiss in
            if dismiss {
                self?.removeFromScreen()
            }
        }).disposed(by: self.disposeBag)

        self.viewModel.contactName.drive(self.nameLabel.rx.text)
            .disposed(by: self.disposeBag)

        self.viewModel.contactName.drive(self.callNameLabel.rx.text)
            .disposed(by: self.disposeBag)

        self.viewModel.callDuration.drive(self.durationLabel.rx.text)
            .disposed(by: self.disposeBag)

        self.viewModel.callDuration.drive(self.callInfoTimerLabel.rx.text)
            .disposed(by: self.disposeBag)

        self.viewModel.bottomInfo
            .observeOn(MainScheduler.instance)
            .bind(to: self.infoBottomLabel.rx.text)
            .disposed(by: self.disposeBag)

        self.viewModel.incomingFrame
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] frame in
            if let image = frame {
                DispatchQueue.main.async {
                    self?.incomingVideo.image = image
                }
            }
        }).disposed(by: self.disposeBag)

        self.viewModel.capturedFrame
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] frame in
            if let image = frame {
                DispatchQueue.main.async {
                    self?.capturedVideo.image = image
                }
            }
        }).disposed(by: self.disposeBag)

        self.viewModel.showCallOptions
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { show in
                if show {
                    self.showContactInfo()
                }
            }).disposed(by: self.disposeBag)

        self.viewModel.videoButtonState
            .observeOn(MainScheduler.instance)
            .bind(to: self.muteVideoButton.rx.image())
            .disposed(by: self.disposeBag)

        self.viewModel.videoMuted
            .observeOn(MainScheduler.instance)
            .bind(to: self.capturedVideo.rx.isHidden)
            .disposed(by: self.disposeBag)

        self.viewModel.audioButtonState
            .observeOn(MainScheduler.instance)
            .bind(to: self.muteAudioButton.rx.image())
            .disposed(by: self.disposeBag)

        self.viewModel.callButtonState
            .observeOn(MainScheduler.instance)
            .bind(to: self.pauseCallButton.rx.image())
            .disposed(by: self.disposeBag)

        self.viewModel.callPaused
            .observeOn(MainScheduler.instance)
            .bind(to: self.callView.rx.isHidden)
            .disposed(by: self.disposeBag)
    }

    func removeFromScreen() {
        self.dismiss(animated: false)
    }

    @objc func screenTaped() {
        self.viewModel.respondOnTap()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        self.viewModel.setCameraOrientation(orientation: UIDevice.current.orientation)
    }

    func showContactInfo() {
        if !self.infoContainer.isHidden {
            task?.cancel()
            self.hideContactInfo()
            return
        }

        self.infoLabelConstraint.constant = -200.00
        self.buttonsContainer.isHidden = false
        self.infoContainer.isHidden = false
        self.view.layoutIfNeeded()

        UIView.animate(withDuration: 0.2, delay: 0.0,
                       options: .curveEaseOut,
                       animations: { [weak self] in
            self?.infoLabelConstraint.constant = 0.00
            self?.view.layoutIfNeeded()
        }, completion: nil)

        task = DispatchWorkItem { self.hideContactInfo() }
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 2, execute: task!)
    }

    func hideContactInfo() {
        UIView.animate(withDuration: 0.2, delay: 0.00,
                       options: .curveEaseOut,
                       animations: { [weak self] in
            self?.infoLabelConstraint.constant = -200.00
            self?.view.layoutIfNeeded()
        }, completion: { [weak self] _ in
            self?.infoContainer.isHidden = true
            self?.buttonsContainer.isHidden = true
        })
    }
}
