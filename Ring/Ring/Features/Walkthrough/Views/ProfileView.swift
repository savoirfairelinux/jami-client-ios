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

struct ProfileView: View {
    @Binding var isPresented: Bool
    @Binding var initialImage: UIImage?
    let saveProfile: (String, UIImage?) -> Void

    init(isPresented: Binding<Bool>,
         initialName: String,
         initialImage: Binding<UIImage?>,
         saveProfile: @escaping (String, UIImage?) -> Void) {
        self._isPresented = isPresented
        self._initialImage = initialImage
        self.saveProfile = saveProfile
        self.profileName = initialName
    }

    @SwiftUI.State private var takenImage: UIImage?
    @SwiftUI.State private var profileName: String

    @SwiftUI.State private var showingImagePicker = false
    @SwiftUI.State private var imagePickerType: PhotoSheetType?

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .center) {
                    Button(action: {
                        showingImagePicker = true
                    }, label: {
                        ZStack {
                            if let image = takenImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                            } else if let image = initialImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                            }
                            Circle()
                                .fill(Color.black.opacity(0.5))
                                .frame(width: 100, height: 100)

                            Image(systemName: "camera.fill")
                                .foregroundColor(.white)
                                .padding(8)
                        }
                    })
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
                        ImagePicker(sourceType: sourceType, showingType: $imagePickerType, image: $takenImage)
                    }

                    Spacer()
                        .frame(height: 40)

                    Text(L10n.AccountPage.profileName)

                    TextField(L10n.AccountPage.profileNamePlaceholder,
                              text: $profileName)
                        .padding()
                        .autocorrectionDisabled(true)
                        .autocapitalization(.none)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                        .padding(.bottom, 20)

                    Spacer()
                }
            }
            .padding()
            .navigationBarTitle(L10n.AccountPage.editProfile,
                                displayMode: .inline)
            .navigationBarItems(
                leading: Button(action: {
                    isPresented = false
                }, label: {
                    Text(L10n.Global.cancel)
                        .foregroundColor(Color(UIColor.label))
                }),
                trailing: Button(action: {
                    saveProfile(profileName, takenImage)
                    isPresented = false
                }, label: {
                    Text(L10n.Global.save)
                        .foregroundColor(.jamiColor)
                })
            )
        }
    }
}
