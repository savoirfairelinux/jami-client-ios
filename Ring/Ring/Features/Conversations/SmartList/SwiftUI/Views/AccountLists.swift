/*
 *  Copyright (C) 2024 Savoir-faire Linux Inc.
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

import SwiftUI

struct AccountLists: View {
    @ObservedObject var model: AccountsViewModel
    var createAccountCallback: (() -> Void)
    var accountSelectedCallback: (() -> Void)
    var closeCallback: (() -> Void)
    let verticalSpacing: CGFloat = 15
    let maxHeight: CGFloat = 300
    let cornerRadius: CGFloat = 16
    let shadowRadius: CGFloat = 6
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 10) {
                accountsView()
                    .accessibilitySortPriority(2)
                newAccountButton()
                    .accessibilitySortPriority(1)
            }
            .accessibility(identifier: SmartListAccessibilityIdentifiers.accountListView)
            .padding(.horizontal, 5)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
    
    private func accountsView() -> some View {
        VStack(spacing: verticalSpacing) {
            headerView()
            accountsList()
        }
        .background(Color(UIColor.systemBackground))
        .cornerRadius(cornerRadius)
        .shadow(radius: shadowRadius)
    }
    
    private func headerView() -> some View {
        HStack {
            Text(model.headerTitle)
                .font(.headline)
            Spacer()
            Button(action: closeCallback) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal)
        .padding(.top)
    }
    
    private func accountsList() -> some View {
        ScrollView {
            VStack {
                ForEach(model.accountsRows, id: \.id) { accountRow in
                    AccountRowView(accountRow: accountRow, model: model, accountSelectedCallback: accountSelectedCallback)
                }
            }
            .frame(minHeight: 0, maxHeight: .infinity)
        }
        .frame(maxHeight: maxHeight)
    }
    
    private func newAccountButton() -> some View {
        Button(action: createAccountCallback) {
            HStack {
                Image(systemName: "plus.circle.fill")
                //Text(L10n.AccountPage.addAccount)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(UIColor.systemBackground))
            .cornerRadius(cornerRadius)
            .shadow(radius: shadowRadius)
        }
    }
}

struct AccountRowView: View {
    @ObservedObject var accountRow: AccountRow
    @ObservedObject var model: AccountsViewModel
    var accountSelectedCallback: (() -> Void)
    let cornerRadius: CGFloat = 8
    
    var body: some View {
        HStack(spacing: 0) {
            Image(uiImage: accountRow.avatar)
                .resizable()
                .scaledToFill()
                .frame(width: accountRow.dimensions.imageSize, height: accountRow.dimensions.imageSize)
                .clipShape(Circle())
            Spacer().frame(width: accountRow.dimensions.spacing)
            VStack(alignment: .leading) {
                Text(accountRow.bestName)
                    .lineLimit(1)
                if let migrationText = accountRow.needMigrate {
                    Text(migrationText)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, accountRow.dimensions.spacing)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .background(backgroundForAccountRow())
        .onTapGesture { [weak model] in
            guard let model = model else { return }
            if model.changeCurrentAccount(accountId: accountRow.id) {
                accountSelectedCallback()
            }
        }
        .accessibilityElement()
        .accessibilityLabel(accountRow.bestName)
    }
    
    private var isSelectedAccount: Bool {
        accountRow.id == model.selectedAccount
    }
    
    private func backgroundForAccountRow() -> some View {
        Group {
            if isSelectedAccount {
                Color(UIColor.systemGray5)
            } else {
                Color.clear
            }
        }
    }
}
