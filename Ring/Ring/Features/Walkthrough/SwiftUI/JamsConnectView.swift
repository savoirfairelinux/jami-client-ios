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
    var body: some View {
        VStack {
            header
            Text("Enter the Jami Account Management Server (JAMS) URL")
                .font(.headline)
                .padding()
            serverView
            Text("Enter JAMS credentials")
                .font(.headline)
                .padding()
            usernameView
            passwordView
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.secondarySystemBackground).ignoresSafeArea())
    }

    private var header: some View {
        HStack {
            cancelButton
            Spacer()
            Text(L10n.LinkToAccountManager.signIn)
            Spacer()
            signinButton
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
        VStack {
            TextField(L10n.Global.enterUsername, text: $username)
                .padding(12)
                .background(Color.white)
                .cornerRadius(12)
        }
    }

    private var serverView: some View {
        VStack {
            TextField(L10n.LinkToAccountManager.accountManagerPlaceholder, text: $server)
                .padding(12)
                .background(Color.white)
                .cornerRadius(12)
        }
    }

    private var passwordView: some View {
        VStack {
            SecureField(L10n.Global.enterPassword, text: $password)
                .padding(12)
                .background(Color.white)
                .cornerRadius(12)
        }
    }
}
