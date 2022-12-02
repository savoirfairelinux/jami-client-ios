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
    @SwiftUI.State private var image: UIImage?
    @SwiftUI.State private var flagScrollPosition: Bool = true
    var swarmViews: [SwarmSettingView] {
        if viewmodel.swarmInfo.participants.value.count == 2 {
            return [.about]
        } else {
            return [.about, .memberList]
        }
    }

    public var body: some View {
        ZStack(alignment: .top) {
            if flagScrollPosition {
                Rectangle()
                    .fill(Color(hex: viewmodel.finalColor) ?? Color(UIColor.systemBackground))
                    .frame(maxWidth: .infinity, maxHeight: 150)
            }
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
                                ImagePicker(sourceType: .photoLibrary, showingType: $showingType, image: $image)
                            } else {
                                ImagePicker(sourceType: .camera, showingType: $showingType, image: $image)
                            }
                        }
                        .onChange(of: image) { _ in
                            viewmodel.updateSwarmAvatar(image: image)
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
                    .background(Color(hex: viewmodel.finalColor))
                    .onTapGesture {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
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
            .gesture(
                DragGesture().onChanged { value in
                    viewmodel.showColorSheet = false
                    if value.translation.height > 0 {
                        self.flagScrollPosition = true
                    } else {
                        self.flagScrollPosition = false

                    }
                }
            )
        }
        if viewmodel.showColorSheet {
            ZStack(alignment: .leading) {
                CustomColorPicker(selectedColor: $viewmodel.finalColor)
                    .padding([.top, .bottom], 5)
                    .frame(height: 70)
                    .background(Color(UIColor.systemGray4))
                    .opacity(0.8)
            }
        }
    }
}

private extension TopProfileView {
    var lightOrDarkColor: Color {
        if viewmodel.finalColor.isEmpty {
            return Color(UIColor.jamiMain)
        } else {
            return Color(hex: viewmodel.finalColor)?.isLight(threshold: 0.5) ?? true ? Color.black : Color.white
        }
    }
    var titleLabel: some View {
        Text(viewmodel.finalTitle)
            .font(Font.title3.weight(.semibold))
            .multilineTextAlignment(.center)
            // Text color.
            .foregroundColor(lightOrDarkColor)
            // Cursor color.
            .accentColor(lightOrDarkColor)
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
            .foregroundColor(lightOrDarkColor)
            // Cursor color.
            .accentColor(lightOrDarkColor)
            .font(Font.title3.weight(.semibold))
            .multilineTextAlignment(.center)
            .padding()
    }

    var descriptionLabel: some View {
        Text(viewmodel.swarmInfo.description.value)
            .font(.body)
            .multilineTextAlignment(.center)
            // Text color.
            .foregroundColor(lightOrDarkColor)
            // Cursor color.
            .accentColor(lightOrDarkColor)
    }

    var descriptionTextField: some View {
        TextField(
            "",
            text: $descriptionTextFieldInput,
            onCommit: {
                viewmodel.description = descriptionTextFieldInput
            })
            .placeholder(when: descriptionTextFieldInput.isEmpty) {
                Text(L10n.Swarm.addDescription).foregroundColor(.gray)
            }
            // Cursor color.
            .accentColor(lightOrDarkColor)
            // Text color.
            .foregroundColor(lightOrDarkColor)
            .font(.body)
            .multilineTextAlignment(.center)
    }
}

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .center,
        @ViewBuilder placeholder: () -> Content) -> some View {

        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}
