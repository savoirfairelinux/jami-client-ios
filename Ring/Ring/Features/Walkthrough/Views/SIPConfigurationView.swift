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

struct SIPConfigurationView: View {
    let dismissAction: () -> Void
    let connectAction: (_ username: String, _ password: String, _ server: String) -> Void
    @SwiftUI.State private var username: String = ""
    @SwiftUI.State private var password: String = ""
    @SwiftUI.State private var server: String = ""
    @SwiftUI.State private var isTextFieldFocused = true
    var body: some View {
        VStack {
            header
            ScrollView(showsIndicators: false) {
                Text(L10n.CreateAccount.sipConfigure)
                    .font(.headline)
                    .padding(.vertical)
                serverView
                usernameView
                passwordView
            }
            .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
    }

    private var header: some View {
        ZStack {
            HStack {
                cancelButton
                Spacer()
                configureButton
            }
            Text(L10n.Account.sipAccount)
        }
        .padding()
    }

    private var cancelButton: some View {
        Button(action: {
            dismissAction()
        }) {
            Text(L10n.Global.cancel)
                .foregroundColor(Color(UIColor.label))
        }
    }

    private var configureButton: some View {
        Button(action: {
            connectAction(username, password, server)
        }) {
            Text(L10n.Account.configure)
                .foregroundColor(.jamiColor)
        }
    }

    private var usernameView: some View {
        CreateAccountTextEditView(text: $username, placeholder: L10n.Global.username)
    }

    private var serverView: some View {
        CreateAccountFocusableTextEditView(text: $server, isTextFieldFocused: $isTextFieldFocused, placeholder: L10n.Account.sipServer)
    }

    private var passwordView: some View {
        CreateAccountPasswordView(text: $password, placeholder: L10n.Global.password)
    }
}

