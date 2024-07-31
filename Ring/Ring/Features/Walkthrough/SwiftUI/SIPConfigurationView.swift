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
    }

    private var header: some View {
        HStack {
            cancelButton
            Spacer()
            Text(L10n.Account.sipAccount)
            Spacer()
            configureButton
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
        VStack {
            TextField(L10n.Global.enterUsername, text: $username)
                .padding(12)
                .background(Color.white)
                .cornerRadius(12)
        }
    }

    private var serverView: some View {
        VStack {
            TextField(L10n.Account.sipServer, text: $server)
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

