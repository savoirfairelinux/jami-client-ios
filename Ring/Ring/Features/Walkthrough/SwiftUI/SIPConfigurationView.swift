//
//  SIPConfigurationView.swift
//  Ring
//
//  Created by kateryna on 2024-08-02.
//  Copyright © 2024 Savoir-faire Linux. All rights reserved.
//

import SwiftUI

struct SIPConfigurationView: View {
    let dismissAction: () -> Void
    let connectAction: (_ username: String, _ password: String, _ server: String) -> Void
    @SwiftUI.State private var username: String = ""
    @SwiftUI.State private var password: String = ""
    @SwiftUI.State private var server: String = ""
    @SwiftUI.State private var isTextFieldFocused = false
    var body: some View {
        VStack {
            header
            ScrollView(showsIndicators: false) {
                Text("Configure an existing SIP account")
                    .font(.headline)
                    .padding(.vertical)
                serverView
                usernameView
                passwordView
            }
            .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.secondarySystemBackground).ignoresSafeArea())
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.isTextFieldFocused = true
            }
        }
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

struct CreateAccountPasswordView: View {
    @Binding var text: String
    var placeholder: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .foregroundColor(Color(UIColor.secondarySystemGroupedBackground))
            PasswordFieldView(text: $text, placeholder: placeholder)
                .padding(.horizontal, 10)
                .padding(.vertical, 12)
        }
    }
}

struct CreateAccountTextEditView: View {
    @Binding var text: String
    var placeholder: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .foregroundColor(Color(UIColor.secondarySystemGroupedBackground))
            TextField(placeholder, text: $text)
                .padding(.horizontal, 10)
                .padding(.vertical, 12)
        }
    }
}

struct CreateAccountFocusableTextEditView: View {
    @Binding var text: String
    @Binding var isTextFieldFocused: Bool
    var placeholder: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .foregroundColor(Color(UIColor.secondarySystemGroupedBackground))
            FocusableTextField(
                text: $text,
                isFirstResponder: $isTextFieldFocused,
                placeholder: placeholder
            )
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
        }
    }
}

