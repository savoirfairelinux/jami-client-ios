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
import Reusable
import RxSwift

class ConferencePendingCallView: UIView {
    @IBOutlet var containerView: UIView!
    @IBOutlet var backgroundView: UIView!
    @IBOutlet var nameLabel: UILabel!
    @IBOutlet var cancelButton: UIButton!
    let disposeBag = DisposeBag()

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.commonInit()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.commonInit()
    }

    func commonInit() {
        Bundle.main.loadNibNamed("ConferencePendingCallView", owner: self, options: nil)
        addSubview(containerView)
        containerView.frame = self.bounds
    }

    var viewModel: ConferencePendingCallViewModel? {
        didSet {
            self.viewModel?.removeView
                .observeOn(MainScheduler.instance)
                .subscribe(onNext: { [weak self] remove in
                    if remove {
                        self?.removeFromSuperview()
                    }
                }).disposed(by: self.disposeBag)
            self.cancelButton.rx.tap
                .subscribe(onNext: { [weak self] in
                    self?.viewModel?.cancelCall()
                    self?.removeFromSuperview()
                }).disposed(by: self.disposeBag)
            self.viewModel?.displayName.drive(self.nameLabel.rx.text)
                .disposed(by: self.disposeBag)
            UIView.animate(withDuration: 1,
                       delay: 0.0,
                       options: [.curveEaseInOut,
                                 .autoreverse,
                                 .repeat],
                       animations: { [weak self] in
                        self?.backgroundView.alpha = 0.1
                       },
                       completion: { [weak self] _ in
                        self?.backgroundView.alpha = 0.7
                   })
        }
    }

}
