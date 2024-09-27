/*
 *  Copyright (C) 2024 Savoir-faire Linux Inc.
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

struct JamsConnectView: View {
    @StateObject var viewModel: ConnectToManagerVM

    init(injectionBag: InjectionBag,
         connectAction: @escaping (_ username: String, _ password: String, _ server: String) -> Void) {
        _viewModel = StateObject(wrappedValue:
                                        ConnectToManagerVM(with: injectionBag))
        viewModel.connectAction = connectAction
    }
    var body: some View {
        VStack {
            header
            ScrollView(showsIndicators: false) {
                Text(L10n.LinkToAccountManager.jamsExplanation)
                    .multilineTextAlignment(.center)
                    .padding(.vertical)
                serverView
                Text(L10n.LinkToAccountManager.enterCredentials)
                    .padding(.vertical)
                usernameView
                passwordView
            }
            .padding(.horizontal)
            .frame(maxWidth: 500)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemGroupedBackground)
                        .ignoresSafeArea()
        )
    }

    private var header: some View {
        ZStack {
            HStack {
                cancelButton
                Spacer()
                signinButton
            }
            Text(L10n.LinkToAccountManager.title)
                .font(.headline)
        }
        .padding()
    }

    private var cancelButton: some View {
        Button(action: {
            viewModel.dismissView()
        }, label: {
            Text(L10n.Global.cancel)
                .foregroundColor(Color(UIColor.label))
        })
    }

    private var signinButton: some View {
        Button(action: {
            viewModel.connect()
        }, label: {
            Text(L10n.LinkToAccountManager.signIn)
                .foregroundColor(viewModel.signInButtonColor)
        })
        .disabled(viewModel.isSignInDisabled)
    }

    private var usernameView: some View {
        WalkthroughTextEditView(text: $viewModel.username,
                                placeholder: L10n.Global.username)
    }

    private var serverView: some View {
        let placeholder = L10n.LinkToAccountManager.accountManagerPlaceholder
        return WalkthroughFocusableTextView(text: $viewModel.server,
                                            isTextFieldFocused: $viewModel.isTextFieldFocused,
                                            placeholder: placeholder)
    }

    private var passwordView: some View {
        WalkthroughPasswordView(text: $viewModel.password,
                                placeholder: L10n.Global.password)
            .padding(.bottom)
    }
}
