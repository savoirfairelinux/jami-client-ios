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
import Reusable
import SwiftyBeaver

class SendFileViewController: UIViewController, StoryboardBased, ViewModelBased {

    var viewModel: SendFileViewModel!
    fileprivate let disposeBag = DisposeBag()
    private let log = SwiftyBeaver.self

    @IBOutlet weak var preview: UIImageView!
    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet weak var sendButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var timerLabel: UILabel!
    @IBOutlet weak var infoLabel: UILabel!
    @IBOutlet weak var placeholderLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.applyL10()
        self.viewModel.capturedFrame
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] frame in
                if let image = frame {
                    DispatchQueue.main.async {
                        self?.preview.image = image
                    }
                }
            }).disposed(by: self.disposeBag)
        self.cancelButton.rx.tap
            .subscribe(onNext: { [unowned self] in
                self.viewModel.cancel()
            }).disposed(by: self.disposeBag)
        self.recordButton.rx.tap
            .subscribe(onNext: { [unowned self] in
                self.viewModel.triggerRecording()
            }).disposed(by: self.disposeBag)
        self.sendButton.rx.tap
            .subscribe(onNext: { [unowned self] in
                self.viewModel.sendFile()
            }).disposed(by: self.disposeBag)

        self.viewModel.hidePreview
            .observeOn(MainScheduler.instance)
            .bind(to: self.preview.rx.isHidden)
            .disposed(by: self.disposeBag)
        self.viewModel.readyToSend
            .map {!$0}
            .drive(self.sendButton.rx.isHidden)
            .disposed(by: self.disposeBag)
        self.viewModel.duration
            .drive(self.timerLabel.rx.text)
            .disposed(by: self.disposeBag)
        self.viewModel.finished
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] finished in
                if finished {
                    self?.dismiss(animated: true, completion: nil)
                }
            }).disposed(by: self.disposeBag)
        self.viewModel.readyToSend
            .drive(self.placeholderLabel.rx.isHidden)
            .disposed(by: self.disposeBag)
        self.viewModel.recording
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] recording in
                if recording {
                    UIView.animate(withDuration: 1,
                                   delay: 0.0,
                                   options: [.curveEaseInOut,
                                             .allowUserInteraction,
                                             .autoreverse,
                                             .repeat],
                                   animations: { [weak self] in
                                    self?.recordButton.alpha = 0.1
                        },
                                   completion: { [weak self] _ in
                                    self?.recordButton.alpha = 1.0
                    })
                } else {
                    self?.recordButton.layer.removeAllAnimations()
                }
            }).disposed(by: self.disposeBag)

        self.viewModel.hideInfo
            .drive(self.infoLabel.rx.isHidden)
            .disposed(by: self.disposeBag)
    }

    func applyL10() {
        self.sendButton.setTitle(L10n.DataTransfer.sendMessage, for: .normal)
        self.cancelButton.setTitle(L10n.Actions.cancelAction, for: .normal)
        self.infoLabel.text = L10n.DataTransfer.infoMessage
    }
}
