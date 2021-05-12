/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
 *
 *  Author: Silbino Gonçalves Matado <silbino.gmatado@savoirfairelinux.com>
 *  Author: Andreas Traczyk <andreas.traczyk@savoirfairelinux.com>
 *  Author: Quentin Muret <quentin.muret@savoirfairelinux.com>
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

    @IBOutlet weak var avatarView: UIView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var acceptButton: UIButton!
    @IBOutlet weak var discardButton: UIButton!
    @IBOutlet weak var banButton: UIButton!

    override func setSelected(_ selected: Bool, animated: Bool) {
        self.backgroundColor = UIColor.jamiUITableViewCellSelection
        UIView.animate(withDuration: 0.35, animations: {
            self.backgroundColor = UIColor.jamiUITableViewCellSelection.lighten(by: 5.0)
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
        drawBanButtonImage()
        self.disposeBag = DisposeBag()
    }

    func drawBanButtonImage() {
        let line = UIBezierPath()
        line.move(to: CGPoint(x: banButton.bounds.width - 13, y: 13))
        line.addLine(to: CGPoint(x: 13, y: banButton.bounds.height - 13))
        line.close()
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = line.cgPath
        shapeLayer.strokeColor = UIColor.red.cgColor
        shapeLayer.lineWidth = 2
        banButton.layer.addSublayer(shapeLayer)
        acceptButton.setBorderPadding(left: 5, right: 5, top: 5, bottom: 5)
        banButton.setBorderPadding(left: 5, right: 5, top: 5, bottom: 5)
        discardButton.setBorderPadding(left: 5, right: 5, top: 5, bottom: 5)
    }

    func configureFromItem(_ item: ContactRequestItem) {
        // avatar
        Observable<(Data?, String)>.combineLatest(item.profileImageData.asObservable(),
                                                  item.userName.asObservable(),
                                                  item.profileName.asObservable()) { profileImage, username, profileName in
                                                    if !profileName.isEmpty {
                                                        return (profileImage, profileName)
                                                    }
                                                    return (profileImage, username)
        }
            .startWith((item.profileImageData.value, item.userName.value))
            .observeOn(MainScheduler.instance)
            .subscribe({ [weak self] profileData -> Void in
                guard let data = profileData.element?.1 else {
                    return
                }
                self?.avatarView.subviews.forEach({ $0.removeFromSuperview() })
                self?.avatarView
                    .addSubview(
                        AvatarView(profileImageData: profileData.element?.0,
                                   username: data,
                                   size: 50))
                return
            })
            .disposed(by: self.disposeBag)

        // name
        item.bestName
            .asObservable()
            .observeOn(MainScheduler.instance)
            .bind(to: self.nameLabel.rx.text)
            .disposed(by: self.disposeBag)

        self.selectionStyle = .none
    }
}
