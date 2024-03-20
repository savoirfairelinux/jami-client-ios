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
    let verticalSpacing: CGFloat = 15
    let maxHeight: CGFloat = 300
    let cornerRadius: CGFloat = 16
    let shadowRadius: CGFloat = 6
    var body: some View {
        VStack(spacing: 10) {
            accountsView()
            newAccountButton()
        }
        .padding(.horizontal, 5)
    }

    @ViewBuilder
    private func accountsView() -> some View {
        VStack {
            Spacer()
                .frame(height: verticalSpacing)
            Text(model.headerTitle)
                .fontWeight(.semibold)
            Spacer()
                .frame(height: verticalSpacing)
            accountsList()
            Spacer()
                .frame(height: verticalSpacing)
        }
        .applyUltraThickMaterialBackgroundForIOS16()
        .cornerRadius(cornerRadius)
        .shadow(radius: shadowRadius)
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func newAccountButton() -> some View {
        Button(action: {
            createAccountCallback()
        }, label: {
            Text(L10n.Smartlist.addAccountButton)
                .lineLimit(1)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(UIColor.systemBackground))
        })
        .frame(minWidth: 100, maxWidth: .infinity)
        .cornerRadius(cornerRadius)
        .shadow(radius: shadowRadius)
    }

    @ViewBuilder
    private func accountsList() -> some View {
        ScrollView {
            VStack {
                ForEach(model.accountsRows, id: \.id) { accountRow in
                    AccountRowView(accountRow: accountRow, model: model)
                }
            }
            .frame(minHeight: 0, maxHeight: .infinity)
        }
        .frame(maxHeight: maxHeight)
    }
}

struct AccountRowView: View {
    @ObservedObject var accountRow: AccountRow
    @ObservedObject var model: AccountsViewModel
    let cornerRadius: CGFloat = 5
    var body: some View {
        HStack(spacing: 0) {
            Image(uiImage: accountRow.avatar)
                .resizable()
                .frame(width: accountRow.dimensions.imageSize, height: accountRow.dimensions.imageSize)
                .clipShape(Circle())
            Spacer().frame(width: accountRow.dimensions.spacing)
            VStack(alignment: .leading) {
                Text(accountRow.bestName)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, accountRow.dimensions.spacing)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .background(backgroundForAccountRow())
        .onTapGesture {
            model.changeCurrentAccount(accountId: accountRow.id)
        }
    }

    private var isSelectedAccount: Bool {
        accountRow.id == model.selectedAccount
    }

    @ViewBuilder
    private func backgroundForAccountRow() -> some View {
        Group {
            if isSelectedAccount {
                Color(UIColor.secondarySystemFill)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    .padding(.horizontal, 5)
            }
        }
    }
}

struct UltraThickMaterialModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 15.0, *) {
            content
                .background(Material.ultraThickMaterial)
        } else {
            content
                .background(Color(UIColor.systemBackground))
        }
    }
}

extension View {
    func applyUltraThickMaterialBackgroundForIOS16() -> some View {
        self.modifier(UltraThickMaterialModifier())
    }
}
