/*
 *  Copyright (C) 2017 Savoir-faire Linux Inc.
 *
 *  Author: Thibault Wittemberg <thibault.wittemberg@savoirfairelinux.com>
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

class CreateAccountViewController: UITableViewController, StoryboardBased, ViewModelBased {

    // MARK: outlets
    @IBOutlet weak var createAccountButton: DesignableButton!
    @IBOutlet weak var createAccountTitle: UILabel!

    // MARK: members
    private let disposeBag = DisposeBag()
    var viewModel: CreateAccountViewModel!

    // MARK: functions
    override func viewDidLoad() {
        super.viewDidLoad()

        // Register cell types
        self.tableView.register(cellType: SwitchCell.self)
        self.tableView.register(cellType: TextFieldCell.self)
        self.tableView.register(cellType: TextCell.self)

        // Bind ViewModel to View
        self.viewModel.createAccountTitle.bind(to: self.createAccountTitle.rx.text).disposed(by: self.disposeBag)
        self.viewModel.createAccountButton.bind(to: self.createAccountButton.rx.title(for: .normal)).disposed(by: self.disposeBag)

        // Bind View Actions to ViewModel
        self.createAccountButton.rx.tap.subscribe(onNext: { [unowned self] in
            self.viewModel.createAccount()
        }).disposed(by: self.disposeBag)

    }
}
