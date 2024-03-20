//
//  AccountLists.swift
//  Ring
//
//  Created by kateryna on 2024-04-05.
//  Copyright © 2024 Savoir-faire Linux. All rights reserved.
//

import SwiftUI

struct AccountLists: View {
    @ObservedObject var model: AccountsViewModel
    var createAccountCallback: (() -> Void)
    let verticalSpacing: CGFloat = 15
    let maxHeight: CGFloat = 300
    let cornerRadius: CGFloat = 16
    let shadowRadius: CGFloat = 10
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
            Text("Accounts")
                .fontWeight(.semibold)
            Spacer()
                .frame(height: verticalSpacing)
            accountsList()
            Spacer()
                .frame(height: verticalSpacing)
        }
        .applyAlertBackgroundMaterial()
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
    let imageSize: CGFloat = 28
    let cornerRadius: CGFloat = 5
    let spacing: CGFloat = 10
    var body: some View {
        HStack(spacing: 0) {
            Image(uiImage: accountRow.avatar)
                .resizable()
                .frame(width: imageSize, height: imageSize)
                .clipShape(Circle())
            Spacer().frame(width: spacing)
            VStack(alignment: .leading) {
                if !accountRow.profileName.isEmpty {
                    Text(accountRow.profileName)
                        .lineLimit(1)
                } else {
                    Text(accountRow.registeredName)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, spacing)
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

struct AlertBackgroundMaterialModifier: ViewModifier {
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
    func applyAlertBackgroundMaterial() -> some View {
        self.modifier(AlertBackgroundMaterialModifier())
    }
}
