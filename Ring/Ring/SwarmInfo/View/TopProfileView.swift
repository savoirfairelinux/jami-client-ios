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
    @SwiftUI.State var showSheet = false
    @SwiftUI.State private var addMorePeople: UIImage = UIImage(asset: Asset.addPeopleInSwarm)!
    @AppStorage("SWARM_COLOR") var swarmColor = Color.blue
    var swarmViews: [SwarmSettingView] {
        if viewmodel.swarmInfo.participants.value.count == 2 {
            return [.about]
        } else {
            return [.about, .memberList]
        }
    }

    public var body: some View {
        ZStack(alignment: .bottomTrailing) {
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
            if viewmodel.swarmInfo.participants.value.count < viewmodel.swarmInfo.maximumLimit && viewmodel.swarmInfo.participants.value.count != 2 {
                Button(action: {
                    showSheet = true
                    viewmodel.getMembersList()
                }, label: {
                    Image(uiImage: addMorePeople)
                        .resizable()
                        .renderingMode(.template)
                        .aspectRatio(contentMode: .fill)
                        .foregroundColor(Color.white)
                        .frame(width: 30, height: 30, alignment: .center)
                })
                .frame(width: 50, height: 50, alignment: .center)
                .background(Color(UIColor.jamiButtonDark))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding()
                .shadow(color: Color.black.opacity(0.3),
                        radius: 3,
                        x: 3,
                        y: 3)
                .sheet(isPresented: $showSheet, content: {
                    let currentCount = viewmodel.memberCount - viewmodel.selections.count
                    if currentCount > 0 {
                        Text(L10n.Swarm.addMorePeople(viewmodel.selections.isEmpty ? viewmodel.memberCount : currentCount))
                            .padding(.top, 20)
                            .font(.system(size: 15.0, weight: .semibold, design: .default))
                    }
                    List {
                        ForEach(viewmodel.participantsRows) { contact in
                            ParticipantListCell(participant: contact, isSelected: viewmodel.selections.contains(contact.id)) {
                                if viewmodel.selections.contains(contact.id) {
                                    viewmodel.selections.removeAll(where: { $0 == contact.id })
                                } else {
                                    if viewmodel.selections.count < viewmodel.memberCount {
                                        viewmodel.selections.append(contact.id)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                    .frame(width: nil, height: nil, alignment: .leading)
                    .accentColor(Color.black)
                    if !viewmodel.selections.isEmpty {
                        addMember()
                    }
                })
            }

        }
    }

    func addMember() -> some View {
        return Button(action: {
                        showSheet = false
                        viewmodel.addMember()}) {
            Text("Add Member")
                .frame(minWidth: 0, maxWidth: .infinity)
                .font(.system(size: 18))
                .padding()
                .foregroundColor(.white)
        }
        .background(Color(UIColor.jamiButtonDark))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.all, 15.0)
    }
}

private extension TopProfileView {
    var titleLabel: some View {
        Text(viewmodel.finalTitle)
            .font(Font.title3.weight(.semibold))
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
            .font(Font.title3.weight(.semibold))
            .multilineTextAlignment(.center)
            .padding()
    }

    var descriptionLabel: some View {
        Text(viewmodel.swarmInfo.description.value)
            .font(.body)
            .multilineTextAlignment(.center)
            // Text color.
            .foregroundColor(.white)
            // Cursor color.
            .accentColor(.white)
    }

    var descriptionTextField: some View {
        TextField(
            L10n.Swarm.addDescription,
            text: $descriptionTextFieldInput,
            onCommit: {
                viewmodel.description = descriptionTextFieldInput
            })
            // Cursor color.
            .accentColor(.white)
            // Text color.
            .foregroundColor(.white)
            .font(.body)
            .multilineTextAlignment(.center)
    }
}
