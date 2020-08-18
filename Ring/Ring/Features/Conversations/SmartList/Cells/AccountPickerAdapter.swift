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

    public func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
        return 60
    }

    public func rowForAccountId(account: AccountModel) -> Int? {
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
        profile
            .map({ [weak self] accountProfile in
                if let photo = accountProfile.photo,
                    let data = NSData(base64Encoded: photo,
                                      options: NSData.Base64DecodingOptions.ignoreUnknownCharacters) as Data? {
                    return UIImage(data: data) ?? UIImage(asset: Asset.fallbackAvatar)!
                }
                guard let account = self?.items[row].account else {
                    return UIImage(asset: Asset.fallbackAvatar)!
                }
                guard let name = accountProfile.alias else {
                    return UIImage.defaultJamiAvatarFor(profileName: nil,
                                                        account: account)}
                let profileName = name.isEmpty ? nil : name
                return UIImage.defaultJamiAvatarFor(profileName: profileName,
                                                    account: account)
            })
            .bind(to: accountView.avatarView.rx.image)
            .disposed(by: DisposeBag())

        profile
            .map({ [weak self] accountProfile in
                if let name = accountProfile.alias, !name.isEmpty {
                    return name
                }
                guard let account = self?.items[row].account else { return "" }
                if !account.registeredName.isEmpty {
                    return account.registeredName
                }
                if let userNameData = UserDefaults.standard.dictionary(forKey: registeredNamesKey),
                    let accountName = userNameData[account.id] as? String,
                    !accountName.isEmpty {
                    return accountName
                }
                return account.jamiId
            })
            .bind(to: accountView.nameLabel.rx.text)
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
