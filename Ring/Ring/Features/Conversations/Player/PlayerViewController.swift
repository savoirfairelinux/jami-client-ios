/*
*  Copyright (C) 2020 Savoir-faire Linux Inc.
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

class PlayerViewController: UIViewController, StoryboardBased, ViewModelBased {
// MARK: - outlets
@IBOutlet weak var playerView: PlayerView!
@IBOutlet private weak var hideButton: UIButton!

// MARK: - members
let disposeBag = DisposeBag()
var viewModel: PlayerControllerModel!
var tapGestureRecognizer: UITapGestureRecognizer!

    override func viewDidLoad() {
        super.viewDidLoad()
        guard let model = self.viewModel.playerViewModel else { return }
        playerView.viewModel = model
        tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(screenTapped))
        self.view.addGestureRecognizer(tapGestureRecognizer)
        self.hideButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.parent?.inputAccessoryView?.isHidden = false
                self?.removeChildController()
            })
            .disposed(by: self.disposeBag)
        hideButton.centerYAnchor.constraint(equalTo: self.playerView.muteAudio.centerYAnchor, constant: 0).isActive = true
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    @objc
    func screenTapped() {
        self.playerView.changeControlsVisibility()
    }
}
