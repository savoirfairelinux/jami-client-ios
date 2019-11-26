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
    @IBOutlet var cancelButton: UIButton!
    @IBOutlet var avatarView: UIView!
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
            Observable<(Profile?, String?)>
                .combineLatest(self.viewModel!
                    .contactImageData!,
                               self.viewModel!
                                .displayName
                                .asObservable()) { profile, username in
                                    return (profile, username)
            }
            .observeOn(MainScheduler.instance)
            .subscribe({ [weak self] profileData -> Void in
                let photoData = NSData(base64Encoded: profileData.element?.0?.photo ?? "", options: NSData.Base64DecodingOptions.ignoreUnknownCharacters) as Data?
                let alias = profileData.element?.0?.alias
                let nameData = profileData.element?.1
                let name = alias != nil ? alias : nameData
                guard let displayName = name else {return}
                self?.avatarView.subviews.forEach({ view in
                    view.removeFromSuperview()
                })
                self?.avatarView.addSubview(
                    AvatarView(profileImageData: photoData,
                               username: displayName,
                               size: 60))
            })
            .disposed(by: self.disposeBag)
        }
    }

}
