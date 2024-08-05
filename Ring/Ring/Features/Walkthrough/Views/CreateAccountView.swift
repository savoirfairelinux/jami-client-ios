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

struct CreateAccountView: View {
    @StateObject var model: CreateAccountViewModel
    let dismissAction: () -> Void
    let createAction: (String) -> Void

    @SwiftUI.State private var isTextFieldFocused = true
    @SwiftUI.State private var name: String = ""

    init(injectionBag: InjectionBag, dismissAction: @escaping () -> Void, createAction: @escaping (String) -> Void) {
        _model = StateObject(wrappedValue: CreateAccountViewModel(with: injectionBag))
        self.dismissAction = dismissAction
        self.createAction = createAction
    }

    var body: some View {
        VStack {
            header
            ScrollView(showsIndicators: false) {
                userNameView
                footerView
            }
            .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .onChange(of: name) { newValue in
            model.usernameUpdated(to: newValue)
        }
    }

    private var header: some View {
        ZStack {
            HStack {
                cancelButton
                Spacer()
                createButton
            }
            Text(L10n.CreateAccount.createAccountFormTitle)
        }
        .padding()
    }

    private var userNameView: some View {
        CreateAccountFocusableTextEditView(text: $name, isTextFieldFocused: $isTextFieldFocused, placeholder: L10n.Global.username)
    }

    private var footerView: some View {
        Text(model.usernameValidationState.message)
            .foregroundColor(Color(model.usernameValidationState.textColor))
            .font(.footnote)
    }

    private var cancelButton: some View {
        Button(action: {
            dismissAction()
        }) {
            Text(L10n.Global.cancel)
                .foregroundColor(Color(UIColor.label))
        }
    }

    private var createButton: some View {
        Button(action: {
            createAction(name)
        }) {
            Text(L10n.Welcome.createAccount)
                .foregroundColor(model.isJoinButtonDisabled ? Color(UIColor.secondaryLabel) : .jamiColor)
        }
        .disabled(model.isJoinButtonDisabled)
    }
}

