//
//  CreateAccountFromBackup.swift
//  Ring
//
//  Created by kateryna on 2024-08-15.
//  Copyright © 2024 Savoir-faire Linux. All rights reserved.
//

import SwiftUI

struct ImportFromArchiveView: View {
    @StateObject var model: CreateAccountViewModel
    let dismissAction: () -> Void
    let createAction: (URL, String) -> Void

    @SwiftUI.State private var password = ""
    @SwiftUI.State private var selectedFileURL: URL?
    @SwiftUI.State private var pickerPresented = false

    init(injectionBag: InjectionBag,
         dismissAction: @escaping () -> Void,
         createAction: @escaping (URL, String) -> Void) {
        _model = StateObject(wrappedValue:
                                CreateAccountViewModel(with: injectionBag))
        self.dismissAction = dismissAction
        self.createAction = createAction
    }

    var body: some View {
        ZStack {
            VStack {
                ScrollView(showsIndicators: false) {
                    Text(L10n.CreateAccount.nameExplanation)
                        .multilineTextAlignment(.center)
                        .padding(.bottom)
                    selectFileButton
                }
                .sheet(isPresented: $pickerPresented) {
                    DocumentPicker(fileURL: $selectedFileURL, type: .item)
                }

                if let selectedFileURL = selectedFileURL {
                    Button(action: {
                        createAction(selectedFileURL, password)
                    }) {
                        Text("Process File")
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
    }

    private var cancelButton: some View {
        Button(action: {
            dismissAction()
        }, label: {
            Text(L10n.Global.cancel)
                .foregroundColor(Color(UIColor.label))
        })
        .accessibilityIdentifier(AccessibilityIdentifiers.cancelCreatingAccount)
    }

    private var selectFileButton: some View {
        Button(action: {
            withAnimation {
                pickerPresented = true
            }
        }, label: {
            Text("select file")
        })
    }
}
