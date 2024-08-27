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
        VStack {
            header
            ScrollView(showsIndicators: false) {
                VStack(spacing: 15) {
                    Text(L10n.ImportFromArchive.explanation)
                        .multilineTextAlignment(.center)
                    selectFileButton
                        .padding(.vertical)
                    Text(L10n.ImportFromArchive.passwordExplanation)
                        .multilineTextAlignment(.center)
                    WalkthroughPasswordView(text: $password,
                                            placeholder: L10n.Global.password)
                        .padding(.bottom)
                }
                .frame(maxWidth: 500)
            }
            .sheet(isPresented: $pickerPresented) {
                DocumentPicker(fileURL: $selectedFileURL, type: .item)
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
                importButton
            }
            Text(L10n.ImportFromArchive.title)
                .font(.headline)
        }
        .padding()
    }

    private var importButton: some View {
        Button(action: {
            if let selectedFileURL = selectedFileURL {
                createAction(selectedFileURL, password)
            }
        }, label: {
            Text(L10n.ImportFromArchive.buttonTitle)
                .foregroundColor(selectedFileURL == nil ?
                                    Color(UIColor.secondaryLabel) :
                                    .jamiColor)
        })
        .disabled(selectedFileURL == nil)
    }

    private var cancelButton: some View {
        Button(action: {
            dismissAction()
        }, label: {
            Text(L10n.Global.cancel)
                .foregroundColor(Color(UIColor.label))
        })
    }

    private var selectFileButton: some View {
        Button(action: {
            withAnimation {
                pickerPresented = true
            }
        }, label: {
            Text(selectedFileURL?.lastPathComponent ?? L10n.ImportFromArchive.selectArchiveButton)
                .foregroundColor(Color(UIColor.label))
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(Color.jamiTertiaryControl)
                .cornerRadius(12)
        })
    }
}
