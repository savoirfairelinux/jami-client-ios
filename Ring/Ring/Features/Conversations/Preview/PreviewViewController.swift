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

enum PrevewType {
    case player
    case image
}

class PreviewViewController: UIViewController, StoryboardBased, ViewModelBased {
// MARK: - outlets
@IBOutlet weak var playerView: PlayerView!
@IBOutlet weak var imageView: UIImageView!
@IBOutlet private weak var hideButton: UIButton!
@IBOutlet weak var imageLeadingConstraint: NSLayoutConstraint!
@IBOutlet weak var imageTrailingConstraint: NSLayoutConstraint!
@IBOutlet weak var imageTopConstraint: NSLayoutConstraint!
@IBOutlet weak var imageBottomConstraint: NSLayoutConstraint!
@IBOutlet weak var backgroundView: UIView!

// MARK: - members
    let disposeBag = DisposeBag()
    var viewModel: PreviewControllerModel!
    var tapGestureRecognizer: UITapGestureRecognizer!
    var type: PrevewType = .player

    override func viewDidLoad() {
        super.viewDidLoad()
        self.playerView.isHidden = self.type == .image
        self.hideButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.parent?.inputAccessoryView?.isHidden = false
                self?.removeChildController()
            })
            .disposed(by: self.disposeBag)
        self.hideButton.centerYAnchor.constraint(equalTo: self.playerView.muteAudio.centerYAnchor, constant: 0).isActive = true
        self.hideButton.setTitle(L10n.Global.close, for: .normal)
        if self.type == .image, let image = self.viewModel.image {
            self.imageView.image = image
            return
        }
        guard let model = self.viewModel.playerViewModel, let playerView = playerView else { return }
        playerView.viewModel = model
        self.tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(screenTapped))
        self.view.addGestureRecognizer(tapGestureRecognizer)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar.alpha = 0
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.navigationController?.navigationBar.alpha = 1
    }

    @objc
    func screenTapped() {
        self.playerView.changeControlsVisibility()
    }

    func resizeViewFromFrame(frame: CGRect) {
        if self.type == .player {
            self.playerView.resizeViewFromFrame(frame: frame, from: self.view.frame)
            return
        }
        let left: CGFloat = frame.origin.x
        let top: CGFloat = frame.origin.y
        let right = self.view.frame.width - frame.origin.x - frame.size.width
        let bottom = self.view.frame.height - frame.origin.y - frame.size.height
        imageLeadingConstraint.constant = left
        imageTrailingConstraint.constant = -right
        imageTopConstraint.constant = top
        imageBottomConstraint.constant = bottom
        self.view.layoutIfNeeded()
        backgroundView.alpha = 0
        UIView.animate(withDuration: 0.2,
                       delay: 0.0,
                       options: [.curveEaseInOut],
                       animations: { [weak self] in
                        guard let self = self else { return }
                        self.imageLeadingConstraint.constant = 0
                        self.imageTrailingConstraint.constant = 0
                        self.imageTopConstraint.constant = 0
                        self.imageBottomConstraint.constant = 0
                        self.backgroundView.alpha = 1
                        self.view.layoutIfNeeded()
        }, completion: nil)
    }
}
