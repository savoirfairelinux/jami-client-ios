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

import Reusable
import RxSwift
import UIKit

class ConversationCell: UITableViewCell, NibReusable {
    @IBOutlet var myLocationSharingIcon: UIImageView!
    @IBOutlet var locationSharingIcon: UIImageView!
    @IBOutlet var avatarView: UIView!
    @IBOutlet var nameLabel: UILabel!
    @IBOutlet var newMessagesIndicator: UIView?
    @IBOutlet var newMessagesLabel: UILabel?
    @IBOutlet var lastMessageDateLabel: UILabel?
    @IBOutlet var lastMessagePreviewLabel: UILabel?
    @IBOutlet var presenceIndicator: UIView?
    @IBOutlet var selectionIndicator: UIButton?
    @IBOutlet var selectionContainer: UIView?

    var avatarSize: CGFloat { return 50 }

    var incomingLocationSharing = false
    var outgoingLocationSharing = false

    override func setSelected(_ selected: Bool, animated _: Bool) {
        let initialColor = selected ? UIColor.jamiUITableViewCellSelection : UIColor
            .jamiUITableViewCellSelection.lighten(by: 5.0)
        let finalColor = selected ? UIColor.jamiUITableViewCellSelection.lighten(by: 5.0) : UIColor
            .clear
        backgroundColor = initialColor
        UIView.animate(withDuration: 0.35, animations: { [weak self] in
            self?.backgroundColor = finalColor
        })
    }

    override func setHighlighted(_ highlighted: Bool, animated _: Bool) {
        if highlighted {
            backgroundColor = UIColor.jamiUITableViewCellSelection
        } else {
            backgroundColor = UIColor.clear
        }
    }

    var disposeBag = DisposeBag()

    override func prepareForReuse() {
        super.prepareForReuse()
        disposeBag = DisposeBag()
        incomingLocationSharing = false
        outgoingLocationSharing = false
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            updateLocationSharingState()
        }
    }

    func updateLocationSharingState() {
        locationSharingIcon.isHidden = !incomingLocationSharing
        myLocationSharingIcon.isHidden = !outgoingLocationSharing
        if incomingLocationSharing {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.locationSharingIcon.stopBlinking()
                self?.locationSharingIcon.blink()
            }
        }
        if outgoingLocationSharing {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.myLocationSharingIcon.stopBlinking()
                self?.myLocationSharingIcon.blink()
            }
        }
    }

    func configureFromItem(_ item: ConversationSection.Item) {
        // avatar
        Observable<(Data?, String)>.combineLatest(item.profileImageData.asObservable(),
                                                  item.bestName.asObservable()) { ($0, $1) }
            .startWith((item.profileImageData.value, item.userName.value))
            .observe(on: MainScheduler.instance)
            .subscribe { [weak self] profileData in
                guard let data = profileData.element?.1 else { return }

                self?.avatarView.subviews.forEach { $0.removeFromSuperview() }
                self?.avatarView.addSubview(AvatarView(profileImageData: profileData.element?.0,
                                                       username: data,
                                                       size: self?.avatarSize ?? 50))
            }
            .disposed(by: disposeBag)

        // presence
        if presenceIndicator != nil {
            item.contactPresence.asObservable()
                .observe(on: MainScheduler.instance)
                .startWith(item.contactPresence.value)
                .subscribe(onNext: { [weak self] presenceStatus in
                    guard let self = self else { return }
                    self.presenceIndicator?.isHidden = presenceStatus == .offline
                    if presenceStatus == .connected {
                        self.presenceIndicator?.backgroundColor = .onlinePresenceColor
                    } else if presenceStatus == .available {
                        self.presenceIndicator?.backgroundColor = .availablePresenceColor
                    }
                })
                .disposed(by: disposeBag)
        }

        // username
        item.bestName.asObservable()
            .observe(on: MainScheduler.instance)
            .bind(to: nameLabel.rx.text)
            .disposed(by: disposeBag)
        nameLabel.lineBreakMode = .byTruncatingTail

        // last message preview
        if let lastMessage = lastMessagePreviewLabel {
            lastMessage.lineBreakMode = .byTruncatingTail
            item.lastMessageObservable
                .observe(on: MainScheduler.instance)
                .startWith(item.lastMessage)
                .bind(to: lastMessage.rx.text)
                .disposed(by: disposeBag)
        }

        if let outgoingLocationSharingImage = Asset.localisationsSendBlack.image
            .withColor(.systemBlue) {
            myLocationSharingIcon.image = outgoingLocationSharingImage
        }

        if let incomingLocationSharingImage = Asset.localisationsReceiveBlack.image
            .withColor(.label) {
            locationSharingIcon.image = incomingLocationSharingImage
        }

        item.showOutgoingLocationSharing
            .distinctUntilChanged()
            .observe(on: MainScheduler.instance)
            .startWith(item.showOutgoingLocationSharing.value)
            .subscribe(onNext: { [weak self] show in
                guard let self = self else { return }
                self.outgoingLocationSharing = show
                self.myLocationSharingIcon.isHidden = !show
                if show {
                    self.myLocationSharingIcon.blink()
                } else {
                    self.myLocationSharingIcon.stopBlinking()
                }
            })
            .disposed(by: disposeBag)

        item.showIncomingLocationSharing
            .distinctUntilChanged()
            .observe(on: MainScheduler.instance)
            .startWith(item.showIncomingLocationSharing.value)
            .subscribe(onNext: { [weak self] show in
                guard let self = self else { return }
                self.incomingLocationSharing = show
                self.locationSharingIcon.isHidden = !show
                if show {
                    self.locationSharingIcon.blink()
                } else {
                    self.locationSharingIcon.stopBlinking()
                }
            })
            .disposed(by: disposeBag)
        selectionStyle = .none
    }
}
