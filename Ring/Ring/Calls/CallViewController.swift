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

class CallViewController: UIViewController, StoryboardBased, ViewModelBased {

    @IBOutlet weak var profileImageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var durationLabel: UILabel!
    @IBOutlet weak var infoBottomLabel: UILabel!
    @IBOutlet weak var cancelButton: UIButton!

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
        self.cancelButton.backgroundColor = UIColor.red
    }

    func setupBindings() {

        //Cancel button action
        self.cancelButton.rx.tap.subscribe(onNext: {
            self.removeFromScreen()
            self.viewModel.cancelCall()
        }).disposed(by: self.disposeBag)

        //Data bindings
        self.viewModel.contactImageData.subscribeOn(MainScheduler.instance).subscribe(onNext: { dataOrNil in
            if let imageData = dataOrNil {
                if let image = UIImage(data: imageData) {
                    self.profileImageView.image = image
                }
            }
        }).disposed(by: self.disposeBag)

        self.viewModel.dismisVC.subscribeOn(MainScheduler.instance).subscribe(onNext: { dismiss in
            if dismiss {
                self.removeFromScreen()
            }
        }).disposed(by: self.disposeBag)

        self.viewModel.contactName.observeOn(MainScheduler.instance).bind(to: self.nameLabel.rx.text)
            .disposed(by: self.disposeBag)

        self.viewModel.callDuration.observeOn(MainScheduler.instance).bind(to: self.durationLabel.rx.text)
            .disposed(by: self.disposeBag)

        self.viewModel.bottomInfo.observeOn(MainScheduler.instance).bind(to: self.infoBottomLabel.rx.text)
            .disposed(by: self.disposeBag)
    }

    func removeFromScreen() {
        self.dismiss(animated: false) {
            print("dismiss")
        }
    }

}
