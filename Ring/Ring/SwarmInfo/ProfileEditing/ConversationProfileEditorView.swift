/*
 *  Copyright (C) 2026-2026 Savoir-faire Linux Inc.
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

struct ConversationProfileEditorView: View {
    private enum Layout {
        static let textEditorLineFragmentPadding: CGFloat = 5
        static let textEditorTopInset: CGFloat = 8
    }

    @ScaledMetric private var descriptionMinHeight: CGFloat = 88

    @StateObject private var model: ConversationProfileEditorVM
    @SwiftUI.State private var showingAvatarOptions = false
    @SwiftUI.State private var imagePickerType: PhotoSheetType?
    @SwiftUI.State private var selectedImage: UIImage?
    @SwiftUI.State private var showingDiscardConfirmation = false

    init(model: ConversationProfileEditorVM) {
        _model = StateObject(wrappedValue: model)
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        Spacer()
                        ConversationProfileEditorAvatar(model: model,
                                                        showingOptions: $showingAvatarOptions)
                        Spacer()
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                Section(header: Text(L10n.ProfileEditor.name), footer: nameFooter) {
                    TextField(model.namePlaceholder, text: $model.name)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled(false)
                        .accessibilityLabel(L10n.ProfileEditor.name)
                }

                if model.isSwarm {
                    Section(header: Text(L10n.ProfileEditor.description)) {
                        descriptionEditor
                    }
                }

                if model.canResetContactProfile {
                    Section {
                        Button(action: model.resetContactProfile) {
                            HStack {
                                Spacer()
                                Text(L10n.ProfileEditor.resetOriginal)
                                    .foregroundColor(Color.jami)
                                Spacer()
                            }
                        }
                        .accessibilityHint(L10n.ProfileEditor.resetOriginalHint)
                    }
                }
            }
            .navigationTitle(model.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Global.cancel, action: cancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.Global.save, action: model.save)
                        .disabled(!model.hasChanges)
                }
            }
        }
        .navigationViewStyle(.stack)
        .accentColor(.jami)
        .interactiveDismissDisabled(model.hasChanges)
        .confirmationDialog("", isPresented: $showingAvatarOptions, titleVisibility: .hidden) {
            Button(L10n.Alerts.profileTakePhoto, action: takePhoto)
            Button(L10n.Alerts.profileUploadPhoto, action: choosePhoto)
            if model.canRemoveAvatar {
                if model.isSwarm {
                    Button(L10n.ProfileEditor.removePicture,
                           role: .destructive,
                           action: model.removeAvatar)
                } else {
                    Button(L10n.ProfileEditor.resetPicture,
                           action: model.removeAvatar)
                }
            }
            Button(L10n.Global.cancel, role: .cancel) {}
        }
        .sheet(item: $imagePickerType) { type in
            ImagePicker(sourceType: type == .gallery ? .photoLibrary : .camera,
                        showingType: $imagePickerType,
                        image: $selectedImage)
        }
        .onChange(of: selectedImage) { image in
            guard let image else { return }
            model.avatar = image
            model.avatarDidChange()
            selectedImage = nil
        }
        .alert(L10n.ProfileEditor.discardTitle, isPresented: $showingDiscardConfirmation) {
            Button(L10n.Global.cancel, role: .cancel) {}
            Button(L10n.ProfileEditor.discard, role: .destructive, action: model.dismiss)
        } message: {
            Text(L10n.ProfileEditor.discardMessage)
        }
        .alert(L10n.ProfileEditor.saveError, isPresented: $model.saveFailed) {}
    }

    private var descriptionEditor: some View {
        ZStack(alignment: .topLeading) {
            if model.description.isEmpty {
                Text(L10n.ProfileEditor.descriptionPlaceholder)
                    .foregroundColor(Color(UIColor.placeholderText))
                    .padding(.leading, Layout.textEditorLineFragmentPadding)
                    .padding(.top, Layout.textEditorTopInset)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            TextEditor(text: $model.description)
                .frame(minHeight: descriptionMinHeight)
                .accessibilityLabel(L10n.ProfileEditor.description)
                .accessibilityValue(model.description.isEmpty
                                        ? L10n.ProfileEditor.descriptionPlaceholder
                                        : model.description)
        }
    }

    @ViewBuilder private var nameFooter: some View {
        if !model.isSwarm {
            Text(L10n.ProfileEditor.localChangesFooter)
        }
    }

    private func cancel() {
        if model.hasChanges {
            showingDiscardConfirmation = true
        } else {
            model.dismiss()
        }
    }

    private func takePhoto() {
        imagePickerType = .picture
    }

    private func choosePhoto() {
        imagePickerType = .gallery
    }
}
