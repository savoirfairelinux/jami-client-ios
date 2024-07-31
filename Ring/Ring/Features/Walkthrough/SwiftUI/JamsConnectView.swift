//
//  ConnectToJamsView.swift
//  Ring
//
//  Created by kateryna on 2024-08-02.
//  Copyright © 2024 Savoir-faire Linux. All rights reserved.
//

import SwiftUI

struct JamsConnectView: View {
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
                Text("Enter the Jami Account Management Server (JAMS) URL")
                    .multilineTextAlignment(.center)
                    .font(.headline)
                    .padding(.vertical)
                serverView
                Text("Enter JAMS credentials")
                    .font(.headline)
                    .padding(.vertical)
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
                signinButton
            }
            Text(L10n.LinkToAccountManager.signIn)
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

    private var signinButton: some View {
        Button(action: {
            connectAction(username, password, server)
        }) {
            Text(L10n.LinkToAccountManager.signIn)
                .foregroundColor((username.isEmpty || password.isEmpty || server.isEmpty) ? Color(UIColor.secondaryLabel) : .jamiColor)
        }
        .disabled(username.isEmpty || password.isEmpty || server.isEmpty)
    }

    private var usernameView: some View {
        CreateAccountTextEditView(text: $username, placeholder: L10n.Global.username)
    }

    private var serverView: some View {
        CreateAccountFocusableTextEditView(text: $server, isTextFieldFocused: $isTextFieldFocused, placeholder: L10n.LinkToAccountManager.accountManagerPlaceholder)
    }

    private var passwordView: some View {
        CreateAccountPasswordView(text: $password, placeholder: L10n.Global.password)
    }
}
