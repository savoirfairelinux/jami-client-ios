/*
 *  Copyright (C) 2024 Savoir-faire Linux Inc.
 *
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
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

struct EditProfileView: View {
    @Binding var isPresented: Bool
    @StateObject var model: EditProfileVM

    init(injectionBag: InjectionBag, account: AccountModel, profileImage: UIImage?, profileName: String, username: String?, isPresented: Binding<Bool>) {
        _model = StateObject(wrappedValue: EditProfileVM(injectionBag: injectionBag, account: account, profileImage: profileImage, profileName: profileName, username: username))
        _isPresented = isPresented
    }
    @SwiftUI.State private var profileImage: Image? = Image(systemName: "person.circle")
    @SwiftUI.State private var profileName: String = ""

    @SwiftUI.State private var showingImagePicker = false
    @SwiftUI.State private var imagePickerType: PhotoSheetType?

    let avatarSize: CGFloat = 100

    var body: some View {
        NavigationView {
            VStack(alignment: .center) {
                Button(action: {
                    showingImagePicker = true
                }) {
                    ZStack {
                        AvatarImageView(model: model, width: avatarSize, height: avatarSize, textSize: 60)
                        Circle()
                            .fill(Color.black.opacity(0.5))
                            .frame(width: avatarSize, height: avatarSize)

                        Image(systemName: "camera.fill")
                            .foregroundColor(.white)
                            .padding(8)
                    }
                }
                .actionSheet(isPresented: $showingImagePicker) {
                    ActionSheet(
                        title: Text(""),
                        buttons: [
                            .default(Text(L10n.Alerts.profileTakePhoto)) {
                                imagePickerType = .picture
                            },
                            .default(Text(L10n.Alerts.profileUploadPhoto)) {
                                imagePickerType = .gallery
                            },
                            .cancel()
                        ]
                    )
                }
                .sheet(item: $imagePickerType) { type in
                    let sourceType: UIImagePickerController.SourceType = type == .picture ? .camera : .photoLibrary
                    ImagePicker(sourceType: sourceType, showingType: $imagePickerType, image: $model.profileImage)
                }

                Spacer()
                    .frame(height: 40)

                Text(L10n.AccountPage.profileName)

                TextField(L10n.AccountPage.profileNamePlaceholder, text: $model.profileName)
                    .padding()
                    .autocorrectionDisabled(true)
                    .autocapitalization(.none)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
                    .padding(.bottom, 20)

                Spacer()
            }
            .padding()
            .navigationBarTitle(L10n.AccountPage.editProfile, displayMode: .inline)
            .navigationBarItems(
                leading: Button(action: {
                    isPresented = false
                }) {
                    Text(L10n.Global.cancel)
                        .foregroundColor(Color(UIColor.label))
                },
                trailing: Button(action: {
                    model.updateProfile()
                    isPresented = false
                }) {
                    Text(L10n.Global.save)
                        .foregroundColor(.jamiColor)
                }
            )
        }
    }
}
