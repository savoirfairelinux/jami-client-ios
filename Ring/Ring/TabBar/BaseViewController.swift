/*
 *  Copyright (C) 2017 Savoir-faire Linux Inc.
 *
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
 *  Author: Romain Bertozzi <romain.bertozzi@savoirfairelinux.com>
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

import RxSwift

protocol TabBarItemViewModel {
    var itemBadgeValueObservable: Observable<String?> { get set }
}

public enum TabBarItemType {
    case chat
    case account
    case contactRequest

    var tabBarItem: UITabBarItem {
        switch self {
        case .chat:
            let conversationIcon = UIImage(asset: Asset.conversationIcon)
            return UITabBarItem(title: L10n.Global.homeTabBarTitle,
                                image: conversationIcon,
                                selectedImage: conversationIcon)
        case .account:
            let accountIcon = UIImage(asset: Asset.accountIcon)
            return UITabBarItem(title: L10n.Global.meTabBarTitle,
                                image: accountIcon,
                                selectedImage: accountIcon)
        case .contactRequest:
            let contactRequestIcon = UIImage(asset: Asset.contactRequestIcon)
            return UITabBarItem(title: L10n.Global.contactRequestsTabBarTitle,
                                image: contactRequestIcon,
                                selectedImage: contactRequestIcon)
        }
    }
}

class BaseViewController: UINavigationController {

    var viewModel: TabBarItemViewModel? {
        didSet {
            _ = self.viewModel?.itemBadgeValueObservable
                .takeUntil(self.rx.deallocated)
                .bind(to: self.tabBarItem.rx.badgeValue)
        }
    }

    convenience init(with type: TabBarItemType) {
        self.init()
        self.navigationBar.isTranslucent = false
        self.tabBarItem = type.tabBarItem
    }

}
