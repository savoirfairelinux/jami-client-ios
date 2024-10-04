/*
 * Copyright (C) 2022 Savoir-faire Linux Inc. *
 *
 * Author: Alireza Toghiani Khorasgani alireza.toghiani@savoirfairelinux.com
 * Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
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

public struct SwarmInfoView: View, StateEmittingView {
    typealias StateEmitterType = ConversationStatePublisher

    @ObservedObject var viewmodel: SwarmInfoVM
    var stateEmitter = ConversationStatePublisher()
    @SwiftUI.State private var selectedView: SwarmSettingView = .about
    @SwiftUI.State private var descriptionTextFieldInput: String = ""
    @SwiftUI.State private var titleTextFieldInput: String = ""
    @SwiftUI.State private var showingOptions = false
    @SwiftUI.State private var showingType: PhotoSheetType?
    @SwiftUI.State private var image: UIImage?
    @SwiftUI.State private var offset: CGFloat = .zero
    @SwiftUI.State private var topViewHeight: CGFloat = 200
    @SwiftUI.State private var minimizedTopView: Bool = false // for lanscape for iphone
    var swarmViews: [SwarmSettingView] {
        if let conversation = viewmodel.conversation, conversation.isCoredialog() {
            return [.about]
        } else {
            return [.about, .memberList]
        }
    }

    public var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack {
                if minimizedTopView {
                    Color(hex: viewmodel.finalColor)
                        .frame(height: 50)
                        .ignoresSafeArea(edges: [.top, .leading, .trailing])
                } else {
                    VStack(spacing: 15) {
                        HStack {
                            Spacer()
                                .frame(height: 20)
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
                                .frame(width: 80, height: 80, alignment: .center)
                                .clipShape(Circle())
                        }
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
                    .frame(height: topViewHeight)
                    .padding([.vertical, .horizontal], 30)
                    .background(Color(hex: viewmodel.finalColor))
                    .ignoresSafeArea(edges: [.top, .leading, .trailing])
                }
                Picker("", selection: $selectedView) {
                    ForEach(swarmViews, id: \.self) {
                        switch $0 {
                        case .about:
                            Text(L10n.Swarm.settings)
                        case .memberList:
                            Text("\(viewmodel.swarmInfo.participants.value.count) \(L10n.Swarm.members)")
                        }
                    }
                }
                .onChange(of: selectedView, perform: { _ in
                    viewmodel.showColorSheet = false
                })
                .pickerStyle(.segmented)
                .padding(.all, 20)

                switch selectedView {
                case .about:
                    SettingsView(viewmodel: viewmodel,
                                 stateEmitter: stateEmitter,
                                 id: viewmodel.swarmInfo.id,
                                 swarmType: viewmodel.swarmInfo.type.value.stringValue)
                case .memberList:
                    MemberList(viewmodel: viewmodel)
                }
            }
            .onLoad {
                descriptionTextFieldInput = viewmodel.swarmInfo.description.value
                titleTextFieldInput = viewmodel.finalTitle
            }
            .onChange(of: viewmodel.finalTitle) { _ in
                titleTextFieldInput = viewmodel.finalTitle
            }
            if !(viewmodel.conversation?.isCoredialog() ?? true) {
                AddMoreParticipantsInSwarm(viewmodel: viewmodel)
            }
            if viewmodel.showColorSheet {
                ZStack(alignment: .bottom) {
                    Rectangle()
                        .foregroundColor(.black.opacity(0.5))
                        .onTapGesture {
                            viewmodel.showColorSheet = false
                            viewmodel.hideShowBackButton(colorPicker: viewmodel.showColorSheet)
                        }
                        .ignoresSafeArea()
                    CustomColorPicker(selectedColor: $viewmodel.selectedColor, currentColor: $viewmodel.finalColor)
                        .frame(height: 70)
                        .background(Color.white)
                        .onChange(of: viewmodel.finalColor) { _ in
                            viewmodel.showColorSheet = false
                            viewmodel.hideShowBackButton(colorPicker: viewmodel.showColorSheet)
                        }
                        .ignoresSafeArea()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            minimizedTopView = shouldMinimizeTop()
        }
        .onAppear(perform: {
            minimizedTopView = shouldMinimizeTop()
        })
        .ignoresSafeArea(edges: [.top])
    }

    func shouldMinimizeTop() -> Bool {
        return UIDevice.current.orientation.isLandscape && UIDevice.current.userInterfaceIdiom == .phone
    }
}

private extension SwarmInfoView {
    var lightOrDarkColor: Color {
        return Color(hex: viewmodel.finalColor)?.isLight(threshold: 0.8) ?? true ? Color(UIColor.jamiMain) : Color.white
    }

    var placeholderColor: Color {
        return viewmodel.finalColor == "#CDDC39" || viewmodel.finalColor == "#FFC107" ? Color.white.opacity(0.7) :
            Color(hex: viewmodel.finalColor)?.isLight(threshold: 0.8) ?? true ? Color.black.opacity(0.5) :
            Color.white.opacity(0.5)
    }
    var titleLabel: some View {
        Text(viewmodel.finalTitle)
            .font(Font.title3.weight(.semibold))
            .multilineTextAlignment(.center)
            // Text color.
            .foregroundColor(lightOrDarkColor)
            // Cursor color.
            .accentColor(lightOrDarkColor)
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
                Text(L10n.Swarm.addDescription).foregroundColor(placeholderColor)
            }
            // Cursor color.
            .accentColor(lightOrDarkColor)
            // Text color.
            .foregroundColor(lightOrDarkColor)
            .font(.body)
            .multilineTextAlignment(.center)
    }
}
