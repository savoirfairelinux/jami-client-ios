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
    @StateObject private var model: ConnectSipVM
    let dismissHandler = DismissHandler()

    init(injectionBag: InjectionBag,
         connectAction: @escaping (_ username: String, _ password: String, _ server: String) -> Void) {
        _model = StateObject(wrappedValue:
                                ConnectSipVM(with: injectionBag, connectAction: connectAction))
    }

    var body: some View {
        VStack {
            header
            ScrollView(showsIndicators: false) {
                Text(L10n.CreateAccount.sipConfigure)
                    .padding(.vertical)
                serverView
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
                configureButton
            }
            Text(L10n.Account.sipAccount)
                .font(.headline)
        }
        .padding()
    }

    private var cancelButton: some View {
        Button(action: {[weak dismissHandler] in
            dismissHandler?.dismissView()
        }, label: {
            Text(L10n.Global.cancel)
                .foregroundColor(Color(UIColor.label))
        })
    }

    private var configureButton: some View {
        Button(action: {[weak dismissHandler, weak model] in
            dismissHandler?.dismissView()
            model?.connect()
        }, label: {
            Text(L10n.Account.configure)
                .foregroundColor(.jamiColor)
        })
    }

    private var usernameView: some View {
        WalkthroughTextEditView(text: $model.username,
                                placeholder: L10n.Global.username)
    }

    private var serverView: some View {
        WalkthroughFocusableTextView(text: $model.server,
                                     isTextFieldFocused: $model.isTextFieldFocused,
                                     placeholder: L10n.Account.sipServer)
    }

    private var passwordView: some View {
        WalkthroughPasswordView(text: $model.password,
                                placeholder: L10n.Global.password)
            .padding(.bottom)
    }
}
