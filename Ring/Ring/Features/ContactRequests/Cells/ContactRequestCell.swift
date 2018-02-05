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
import Reusable
import RxSwift

class ContactRequestCell: UITableViewCell, NibReusable {

    @IBOutlet weak var fallbackAvatar: UILabel!
    @IBOutlet weak var profileImageView: UIImageView!
    @IBOutlet weak var fallbackAvatarImage: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var acceptButton: UIButton!
    @IBOutlet weak var discardButton: UIButton!
    @IBOutlet weak var banButton: UIButton!

    override func setSelected(_ selected: Bool, animated: Bool) {
        let fallbackAvatarBGColor = self.fallbackAvatar.backgroundColor
        super.setSelected(selected, animated: animated)
        self.fallbackAvatar.backgroundColor = fallbackAvatarBGColor
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        let fallbackAvatarBGColor = self.fallbackAvatar.backgroundColor
        super.setSelected(highlighted, animated: animated)
        self.fallbackAvatar.backgroundColor = fallbackAvatarBGColor
    }

    var disposeBag = DisposeBag()

    override func prepareForReuse() {
        self.disposeBag = DisposeBag()
    }

    func initFromItem(_ item: ContactRequestItem) {
        item.userName
            .asObservable()
            .observeOn(MainScheduler.instance)
            .bind(to: self.nameLabel.rx.text)
            .disposed(by: self.disposeBag)

        // Avatar placeholder initial
        self.fallbackAvatar.text = nil
        self.fallbackAvatarImage.isHidden = true
        let name = item.userName.value
        let scanner = Scanner(string: name.toMD5HexString().prefixString())
        var index: UInt64 = 0
        if scanner.scanHexInt64(&index) {
            self.fallbackAvatar.isHidden = false
            self.fallbackAvatar.backgroundColor = avatarColors[Int(index)]
            if item.contactRequest.ringId != name {
                self.fallbackAvatar.text = name.prefixString().capitalized
            } else {
                self.fallbackAvatarImage.isHidden = false
            }
        }

        item.userName.asObservable()
            .observeOn(MainScheduler.instance)
            .filter({ [weak item] userName in
                return userName != item?.contactRequest.ringId
            })
            .map { value in value.prefixString().capitalized }
            .bind(to: self.fallbackAvatar.rx.text)
            .disposed(by: self.disposeBag)

        item.userName.asObservable()
            .observeOn(MainScheduler.instance)
            .map { [weak item] userName in userName != item?.contactRequest.ringId }
            .bind(to: self.fallbackAvatarImage.rx.isHidden)
            .disposed(by: self.disposeBag)

        // UIColor that observes "best Id" prefix
        item.userName.asObservable()
            .observeOn(MainScheduler.instance)
            .map { name in
                let scanner = Scanner(string: name.toMD5HexString().prefixString())
                var index: UInt64 = 0
                if scanner.scanHexInt64(&index) {
                    return avatarColors[Int(index)]
                }
                return defaultAvatarColor
            }
            .subscribe(onNext: { backgroundColor in
                self.fallbackAvatar.backgroundColor = backgroundColor
            })
            .disposed(by: self.disposeBag)

        // Set image if any
        if let imageData = item.profileImageData.value {
            if let image = UIImage(data: imageData) {
                self.profileImageView.image = image
                self.fallbackAvatar.isHidden = true
            }
        } else {
            self.fallbackAvatar.isHidden = false
            self.profileImageView.image = nil
        }

        item.profileImageData.asObservable()
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { data in
                if let imageData = data {
                    if let image = UIImage(data: imageData) {
                        UIView.transition(with: self.profileImageView,
                                          duration: 1.0,
                                          options: .transitionCrossDissolve,
                                          animations: {
                                            self.profileImageView.image = image
                        }, completion: { _ in
                            self.fallbackAvatar.isHidden = true
                        })
                    }
                } else {
                    self.fallbackAvatar.isHidden = false
                    self.profileImageView.image = nil
                }
            }).disposed(by: self.disposeBag)
    }
}
