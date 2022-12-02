/*
 * Copyright (C) 2022 Savoir-faire Linux Inc. *
 *
 * Author: Alireza Toghiani Khorasgani alireza.toghiani@savoirfairelinux.com *
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version. *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details. *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

import SwiftUI

enum SwarmSettingView: String {
    case about
    case memberList
}

// swiftlint:disable closure_body_length
public struct TopProfileView: View {

    @StateObject var viewmodel: SwarmInfoViewModel
    @SwiftUI.State private var selectedView: SwarmSettingView = .about
    @SwiftUI.State private var descriptionTextFieldInput: String = ""
    @SwiftUI.State private var titleTextFieldInput: String = ""
    @SwiftUI.State private var showingOptions = false
    @SwiftUI.State private var showingType: PhotoSheetType?
    @SwiftUI.State private var imageData: Data = Data()
    @AppStorage("SWARM_COLOR") var swarmColor = Color.blue
    var swarmViews: [SwarmSettingView] {
        if viewmodel.swarmInfo.participants.value.count == 2 {
            return [.about]
        } else {
            return [.about, .memberList]
        }
    }

    public var body: some View {
        ScrollView {
            VStack {
                VStack {
                    HStack {
                        Spacer()
                    }
                    Button {
                        if viewmodel.isAdmin {
                            showingOptions = true
                        }
                    } label: {
                        Image(uiImage: viewmodel.finalAvatar)
                            .renderingMode(.original)
                            .resizable()
                            .scaledToFill()
                            .frame(width: viewmodel.swarmInfo.avatarHeight, height: viewmodel.swarmInfo.avatarHeight, alignment: .center)
                            .clipShape(Circle())
                    }
                    .padding(.vertical)
                    .actionSheet(isPresented: $showingOptions) {
                        ActionSheet(
                            title: Text(""),
                            buttons: [
                                .default(Text(L10n.Alerts.profileTakePhoto)) {
                                    showingType = .picture
                                },
                                .default(Text(L10n.Alerts.profileUploadPhoto)) {
                                    showingType = .gallery
                                },
                                .cancel()
                            ]
                        )
                    }
                    .sheet(item: $showingType) { type in
                        if type == .gallery {
                            ImagePicker(sourceType: .photoLibrary, showingType: $showingType, image: $imageData)
                        } else {
                            ImagePicker(sourceType: .camera, showingType: $showingType, image: $imageData)
                        }
                    }
                    .onChange(of: imageData) { _ in
                        print("Avatar changed to \(imageData)!")
                        viewmodel.updateSwarmAvatar(imageData: imageData)
                    }

                    if viewmodel.isAdmin {
                        titleTextField
                    } else {
                        titleLabel
                    }

                    Group {
                        if viewmodel.isAdmin {
                            descriptionTextField
                        } else {
                            descriptionLabel
                        }
                    }
                }
                .padding([.vertical, .horizontal], 30)
                .background(swarmColor)
                .onTapGesture {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }

                Picker("", selection: $selectedView) {
                    ForEach(swarmViews, id: \.self) {
                        switch $0 {
                        case .about:
                            Text(L10n.Swarm.about)
                        case .memberList:
                            Text("\(viewmodel.swarmInfo.participants.value.count) \(L10n.Swarm.members)")
                        }
                    }
                }
                .pickerStyle(.segmented)
                .padding(.all, 20)

                switch selectedView {
                case .about:
                    SettingsView(viewmodel: viewmodel, id: viewmodel.swarmInfo.id, swarmType: viewmodel.swarmInfo.type.value.stringValue)
                case .memberList:
                    MemberList(members: viewmodel.swarmInfo.participants.value)
                }
            }
            .onLoad {
                descriptionTextFieldInput = viewmodel.swarmInfo.description.value
                titleTextFieldInput = viewmodel.finalTitle
            }
            .onChange(of: viewmodel.finalTitle) { _ in
                titleTextFieldInput = viewmodel.finalTitle
            }
        }
    }
}

private extension TopProfileView {
    var titleLabel: some View {
        Text(viewmodel.finalTitle)
            .font(.system(.title3, design: .serif))
            .multilineTextAlignment(.center)
            // Text color.
            .foregroundColor(.white)
            // Cursor color.
            .accentColor(.white)
            .padding()
    }

    var titleTextField: some View {
        TextField(
            "",
            text: $titleTextFieldInput,
            onCommit: {
                viewmodel.title = titleTextFieldInput
            })
            // Text color.
            .foregroundColor(.white)
            // Cursor color.
            .accentColor(.white)
            .font(.system(.title3, design: .serif))
            .multilineTextAlignment(.center)
            .padding()
    }

    var descriptionLabel: some View {
        Text(viewmodel.swarmInfo.description.value)
            .font(.system(.body, design: .serif))
            .multilineTextAlignment(.center)
            // Text color.
            .foregroundColor(.white)
            // Cursor color.
            .accentColor(.white)
    }

    var descriptionTextField: some View {
        TextField(
            "Add Description",
            text: $descriptionTextFieldInput,
            onCommit: {
                viewmodel.description = descriptionTextFieldInput
            })
            // Cursor color.
            .accentColor(.white)
            // Text color.
            .foregroundColor(.white)
            .font(.system(.body, design: .serif))
            .multilineTextAlignment(.center)
    }
}

// struct TopProfileView_Previews: PreviewProvider {
//    static var previews: some View {
//        TopProfileView(viewmodel: SwarmInfoViewModel())
//            .previewLayout(.sizeThatFits)
//    }
// }
