/*
 * Copyright (C) 2023 Savoir-faire Linux Inc. *
 *
 * Author: Alireza Toghiani Khorasgani alireza.toghiani@savoirfairelinux.com
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version. *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details. *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

import UIKit
import RxSwift
import Reusable

class ConversationTableViewCell: UITableViewCell, NibReusable {

    @IBOutlet weak var avatarView: UIView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var selectionIndicator: UIButton?
    @IBOutlet weak var selectionContainer: UIView?

    var avatarSize: CGFloat { return 50 }

    override func setSelected(_ selected: Bool, animated: Bool) {
        let initialColor = selected ? UIColor.jamiUITableViewCellSelection : UIColor.jamiUITableViewCellSelection.lighten(by: 5.0)
        let finalColor = selected ? UIColor.jamiUITableViewCellSelection.lighten(by: 5.0) : UIColor.clear
        self.backgroundColor = initialColor
        UIView.animate(withDuration: 0.35, animations: { [weak self] in
            self?.backgroundColor = finalColor
        })
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        if highlighted {
            self.backgroundColor = UIColor.jamiUITableViewCellSelection
        } else {
            self.backgroundColor = UIColor.clear
        }
    }

    var disposeBag = DisposeBag()

    override func prepareForReuse() {
        super.prepareForReuse()
        self.disposeBag = DisposeBag()
    }

    func configureFromItem(_ item: ShareContactPickerSection.Item) {
        // avatar
        Observable<(UIImage?, String)>.combineLatest(item.finalAvatar.asObservable(),
                                                     item.title.asObservable()) { ($0, $1) }
            .startWith((UIImage(), ""))
            .observe(on: MainScheduler.instance)
            .subscribe { [weak self] profileData in
                let data = profileData.1

                self?.avatarView.subviews.forEach({ $0.removeFromSuperview() })
                self?.avatarView.addSubview(AvatarView(profileImageData: profileData.0?.pngData(),
                                                       username: data,
                                                       size: self?.avatarSize ?? 50))
            }
            .disposed(by: self.disposeBag)

        // username
        item.finalTitle.asObservable()
            .observe(on: MainScheduler.instance)
            .bind(to: self.nameLabel.rx.text)
            .disposed(by: self.disposeBag)
        self.nameLabel.lineBreakMode = .byTruncatingTail

        self.selectionStyle = .none
    }
}
