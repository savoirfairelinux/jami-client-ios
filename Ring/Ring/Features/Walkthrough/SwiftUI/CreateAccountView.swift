//
//  CreateAccountView.swift
//  Ring
//
//  Created by kateryna on 2024-07-31.
//  Copyright © 2024 Savoir-faire Linux. All rights reserved.
//

import SwiftUI

struct CreateAccountView: View {
    @StateObject var model: CreateAccountViewModel
    let dismissAction: () -> Void
    let createAction: (String) -> Void

    @SwiftUI.State private var isTextFieldFocused = false
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
        .background(Color(UIColor.secondarySystemBackground).ignoresSafeArea())
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.isTextFieldFocused = true
            }
        }
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

