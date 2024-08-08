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
    let dismissAction: () -> Void
    let connectAction: (_ username: String,
                        _ password: String,
                        _ server: String) -> Void
    @SwiftUI.State private var username: String = ""
    @SwiftUI.State private var password: String = ""
    @SwiftUI.State private var server: String = ""
    @SwiftUI.State private var isTextFieldFocused = true
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
            dismissAction()
        }, label: {
            Text(L10n.Global.cancel)
                .foregroundColor(Color(UIColor.label))
        })
    }

    private var signinButton: some View {
        Button(action: {
            connectAction(username, password, server)
        }, label: {
            Text(L10n.LinkToAccountManager.signIn)
                .foregroundColor(signInDisabled ?
                                    Color(UIColor.secondaryLabel) :
                                    .jamiColor)
        })
        .disabled(signInDisabled)
    }

    private var usernameView: some View {
        WalkthroughTextEditView(text: $username,
                                placeholder: L10n.Global.username)
    }

    private var serverView: some View {
        let placeholder = L10n.LinkToAccountManager.accountManagerPlaceholder
        return WalkthroughFocusableTextView(text: $server,
                                            isTextFieldFocused: $isTextFieldFocused,
                                            placeholder: placeholder)
    }

    private var passwordView: some View {
        WalkthroughPasswordView(text: $password,
                                placeholder: L10n.Global.password)
            .padding(.bottom)
    }

    private var signInDisabled: Bool {
        username.isEmpty || password.isEmpty || server.isEmpty
    }
}
