/*
 *  Copyright (C) 2017 Savoir-faire Linux Inc.
 *
 *  Author: Silbino Gonçalves Matado <silbino.gmatado@savoirfairelinux.com>
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

class CallViewController: UIViewController, StoryboardBased, ViewModelBased {

    @IBOutlet weak var profileImageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var infoLabel: UILabel!
    @IBOutlet weak var durationLabel: UILabel!
    @IBOutlet weak var infoBottomLabel: UILabel!
    @IBOutlet weak var answerButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var ignoreButton: UIButton!

    var viewModel: CallViewModel!

    fileprivate let disposeBag = DisposeBag()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupUI()
        self.setupBindings()
    }

    override func viewDidDisappear(_ animated: Bool) {
       super.viewWillDisappear(animated)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    func setupUI() {
        self.ignoreButton.backgroundColor = UIColor.red
        self.cancelButton.backgroundColor = UIColor.red
        self.answerButton.backgroundColor = UIColor.green
    }

    func setupBindings() {

        //Ignore button action
        self.ignoreButton.rx.tap.subscribe(onNext: {
            self.viewModel.ignoreCall()
        }).disposed(by: self.disposeBag)

        //Cancel button action
        self.cancelButton.rx.tap.subscribe(onNext: {
            self.viewModel.cancelCall()
        }).disposed(by: self.disposeBag)

        //Answer button action
        self.answerButton.rx.tap.subscribe(onNext: {
            self.viewModel.answerCall()
        }).disposed(by: self.disposeBag)

        //Show or hide buttons
        self.viewModel.hideAnswerButton.observeOn(MainScheduler.instance).bind(to: self.answerButton.rx.isHidden)
            .disposed(by: self.disposeBag)

        self.viewModel.hideCancelButton.observeOn(MainScheduler.instance).bind(to: self.cancelButton.rx.isHidden)
            .disposed(by: self.disposeBag)

        self.viewModel.hideIgnoreButton.observeOn(MainScheduler.instance).bind(to: self.ignoreButton.rx.isHidden)
            .disposed(by: self.disposeBag)

        //Data bindings
        self.viewModel.contactImageData.subscribeOn(MainScheduler.instance).subscribe(onNext: { dataOrNil in
            if let imageData = dataOrNil {
                if let image = UIImage(data: imageData) {
                    self.profileImageView.image = image
                }
            }
        }).disposed(by: self.disposeBag)

        self.viewModel.contactName.observeOn(MainScheduler.instance).bind(to: self.nameLabel.rx.text)
            .disposed(by: self.disposeBag)

        self.viewModel.callDuration.observeOn(MainScheduler.instance).bind(to: self.durationLabel.rx.text)
            .disposed(by: self.disposeBag)

        self.viewModel.info.observeOn(MainScheduler.instance).bind(to: self.infoLabel.rx.text)
            .disposed(by: self.disposeBag)

        self.viewModel.bottomInfo.observeOn(MainScheduler.instance).bind(to: self.infoBottomLabel.rx.text)
            .disposed(by: self.disposeBag)
    }

}
