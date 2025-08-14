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
import RxSwift
import RxDataSources
import RxCocoa

struct AccountItem {
    let account: AccountModel
    let profileObservable: Observable<Profile>
}

final class AccountPickerAdapter: NSObject, UIPickerViewDataSource, UIPickerViewDelegate, RxPickerViewDataSourceType, SectionedViewDataSourceType {
    typealias Element = [AccountItem]

    private var items: [AccountItem] = []

    func model(at indexPath: IndexPath) throws -> Any {
        return items[indexPath.row]
    }

    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return items.count
    }

    func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
        return 60
    }

    func rowForAccountId(account: AccountModel) -> Int? {
        return self.items.firstIndex { $0.account === account }
    }

    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
        let accountView: AccountItemView
        if let oldView = view as? AccountItemView {
            accountView = oldView
        } else {
            accountView = AccountItemView()
        }
        let hideMigrationLabel = items[row].account.status != .errorNeedMigration
        accountView.needMigrateLabel.isHidden = hideMigrationLabel
        let profile = items[row].profileObservable
        let account = items[row].account
        let jamiId: String = { (account: AccountModel) -> String in
            if !account.registeredName.isEmpty {
                return account.registeredName
            }
            if let userNameData = UserDefaults.standard.dictionary(forKey: registeredNamesKey),
               let accountName = userNameData[account.id] as? String,
               !accountName.isEmpty {
                return accountName
            }
            return account.jamiId
        }(account)
        accountView.idLabel.text = jamiId
        profile
            .map({ [weak self] accountProfile in
                if let data = accountProfile.photo?.toImageData(),
                   let image = UIImage(data: data) {
                    return image
                }
                let account = self?.items[row].account
                return UIImage.defaultJamiAvatarFor(profileName: accountProfile.alias, account: account, size: 30)
            })
            .bind(to: accountView.avatarView.rx.image)
            .disposed(by: DisposeBag())

        profile
            .map({ accountProfile -> String in
                if let name = accountProfile.alias, !name.isEmpty {
                    return name
                }
                return jamiId
            })
            .subscribe(onNext: { [weak accountView] (name) in
                accountView?.idLabel.isHidden = name == jamiId
                accountView?.nameLabel.text = name
            })
            .disposed(by: DisposeBag())
        return accountView
    }

    func pickerView(_ pickerView: UIPickerView, observedEvent: Event<Element>) {
        Binder(self) { (adapter, items) in
            adapter.items = items
            pickerView.reloadAllComponents()
        }.on(observedEvent)
    }
}
