/*
 *  Copyright (C) 2026 Savoir-faire Linux Inc.
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

import SwiftUI
import UIKit

/// The smart list's bar actions. The bar's own menu and the overflow menu
/// iPadOS shows for a narrow bar are both built from these lists.
enum SmartListMenuAction: Hashable {
    case compose
    case contacts
    case newGroup
    case inviteFriends
    case accounts
    case settings
    case aboutJami
    case donate

    /// The button shown beside the menu.
    static func primary(isSip: Bool) -> SmartListMenuAction {
        return isSip ? .contacts : .compose
    }

    static func menu(isSip: Bool) -> [SmartListMenuAction] {
        let common: [SmartListMenuAction] = [.accounts, .settings, .aboutJami, .donate]
        return isSip ? common : [.newGroup, .inviteFriends] + common
    }

    var title: String {
        switch self {
        case .compose: return L10n.Smartlist.newConversation
        case .contacts: return L10n.ContactPicker.contacts
        case .newGroup: return L10n.Swarm.newGroup
        case .inviteFriends: return L10n.Smartlist.inviteFriends
        case .accounts: return L10n.Smartlist.accounts
        case .settings: return L10n.AccountPage.settingsHeader
        case .aboutJami: return L10n.Smartlist.aboutJami
        case .donate: return L10n.Global.supportJami
        }
    }

    var image: UIImage? {
        switch self {
        case .compose: return UIImage(systemName: "square.and.pencil")
        case .contacts: return UIImage(asset: Asset.phoneBook)
        case .newGroup: return UIImage(systemName: "person.2")
        case .inviteFriends: return UIImage(systemName: "envelope.open")
        case .accounts: return UIImage(systemName: "list.bullet")
        case .settings: return UIImage(systemName: "person.circle")
        case .aboutJami: return Self.jamiIcon
        case .donate: return UIImage(systemName: "heart")
        }
    }

    private static let jamiIcon = UIImage(asset: Asset.jamiIcon)?
        .resizeImageWith(newSize: CGSize(width: 20, height: 20), opaque: false)
}

/// Installs the trailing smart list bar buttons as a UIKit bar item. The
/// buttons are the SwiftUI view the bar always showed; installing it from
/// UIKit lets its group provide the menu iPadOS shows when a narrow bar
/// folds it into its overflow button.
enum SmartListNavigationItems {
    static func install(on controller: UIViewController, model: ConversationsViewModel) {
        let perform: (SmartListMenuAction) -> Void = { [weak model, weak controller] action in
            guard let model = model, let controller = controller else { return }
            Self.perform(action, model: model, presenter: controller)
        }
        let trailing = HostingBarButtonItem(SmartListTrailingBarItems(model: model, perform: perform))
        controller.installTrailingBarItem(trailing, menuRepresentation: overflowMenu(model: model, perform: perform))
    }

    /// The compose (or contacts) button followed by the menu's items, flat,
    /// built when shown so it matches the current account.
    private static func overflowMenu(model: ConversationsViewModel,
                                     perform: @escaping (SmartListMenuAction) -> Void) -> UIMenu {
        let items = UIDeferredMenuElement.uncached { [weak model] completion in
            guard let model = model else {
                completion([])
                return
            }
            let isSip = model.isSipAccount()
            let menu = SmartListMenuAction.menu(isSip: isSip).map { menuAction($0, perform: perform) }
            completion([menuAction(.primary(isSip: isSip), perform: perform),
                        UIMenu(options: .displayInline, children: menu)])
        }
        return UIMenu(options: .displayInline, children: [items])
    }

    private static func menuAction(_ action: SmartListMenuAction,
                                   perform: @escaping (SmartListMenuAction) -> Void) -> UIAction {
        return UIAction(title: action.title, image: action.image) { _ in
            perform(action)
        }
    }

    private static func perform(_ action: SmartListMenuAction,
                                model: ConversationsViewModel,
                                presenter: UIViewController) {
        switch action {
        case .compose:
            model.barActions.send(.compose)
        case .contacts:
            model.barActions.send(.contacts)
        case .newGroup:
            model.stateEmitter.createSwarm()
        case .inviteFriends:
            SharedActionsPresenter.shareAccountInfo(onViewController: presenter,
                                                    sourceView: presenter.view,
                                                    content: [model.accountInfoToShare])
        case .accounts:
            model.barActions.send(.toggleAccounts)
        case .settings:
            model.showAccount(publisher: model.stateEmitter)
        case .aboutJami:
            model.stateEmitter.openAboutJami()
        case .donate:
            model.donate()
        }
    }
}
