/*
 *  Copyright (C) 2017 Savoir-faire Linux Inc.
 *
 *  Author: Edric Ladent-Milaret <edric.ladent-milaret@savoirfairelinux.com>
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

class MeViewController: EditProfileViewController, StoryboardBased, ViewModelBased {

    // MARK: - outlets
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var ringIdLabel: UILabel!

    // MARK: - members
    var viewModel: MeViewModel!
    fileprivate let disposeBag = DisposeBag()

    // MARK: - functions
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = L10n.Global.meTabBarTitle
        self.navigationItem.title = L10n.Global.meTabBarTitle
        self.setupUI()
    }

    override func setupUI() {
        self.viewModel.userName.asObservable()
            .bind(to: self.nameLabel.rx.text)
            .disposed(by: disposeBag)

        self.viewModel.ringId.asObservable()
            .bind(to: self.ringIdLabel.rx.text)
            .disposed(by: disposeBag)

        super.setupUI()
    }
}
