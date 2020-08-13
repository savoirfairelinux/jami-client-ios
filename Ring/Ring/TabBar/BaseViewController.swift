/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
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

import Foundation
import RxSwift

protocol TabBarItemViewModel {
    var itemBadgeValue: Observable<String?> { get set }
}

public enum TabBarItemType {
    case chat
    case account
    case contactRequest

    var tabBarItem: UITabBarItem {
        switch self {
        case .chat:
            return UITabBarItem(title: L10n.Global.homeTabBarTitle, image: UIImage(named: "conversation_icon"), selectedImage: UIImage(named: "conversation_icon"))
        case .account:
            return UITabBarItem(title: L10n.Global.meTabBarTitle, image: UIImage(named: "account_icon"), selectedImage: UIImage(named: "account_icon"))
        case .contactRequest:
            return UITabBarItem(title: L10n.Global.contactRequestsTabBarTitle, image: UIImage(named: "contact_request_icon"), selectedImage: UIImage(named: "contact_request_icon"))
        }
    }
}

class BaseViewController: UINavigationController {

    let disposeBag = DisposeBag()

    var viewModel: TabBarItemViewModel? {
        didSet {
            self.viewModel?.itemBadgeValue.bind(to: self.tabBarItem.rx.badgeValue)
                .disposed(by: self.disposeBag)
        }
    }
    convenience init(with type: TabBarItemType) {
        self.init()
        self.navigationBar.isTranslucent = true
        self.tabBarItem = type.tabBarItem
        self.view.backgroundColor = UIColor.jamiBackgroundColor
    }
}
