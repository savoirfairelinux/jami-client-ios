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
import Combine

// MARK: - Enums and Types

/// Defines the available views in the swarm settings
enum SwarmSettingView: String, CaseIterable {
    case about
    case memberList
    
    var title: String {
        switch self {
        case .about:
            return L10n.Swarm.settings
        case .memberList:
            return L10n.Swarm.members
        }
    }
}

// MARK: - SwarmInfoView

public struct SwarmInfoView: View, StateEmittingView {
    // MARK: - Type Definitions
    typealias StateEmitterType = ConversationStatePublisher
    
    // MARK: - Constants
    private enum Layout {
        static let avatarSize: CGFloat = 80
        static let minimizedTopHeight: CGFloat = 50
        static let contentPadding: CGFloat = 20
        static let segmentedControlPadding: CGFloat = 20
        static let verticalSpacing: CGFloat = 20
        static let callButtonSize: CGFloat = 45
        static let callButtonSpacing: CGFloat = 20
    }
    
    // MARK: - Properties
    @ObservedObject var viewmodel: SwarmInfoVM
    let stateEmitter = ConversationStatePublisher()
    
    // MARK: - State
    @SwiftUI.State private var selectedView: SwarmSettingView = .about
    @SwiftUI.State private var descriptionTextFieldInput: String = ""
    @SwiftUI.State private var titleTextFieldInput: String = ""
    @SwiftUI.State private var showingOptions = false
    @SwiftUI.State private var showingType: PhotoSheetType?
    @SwiftUI.State private var image: UIImage?
    @SwiftUI.State private var minimizedTopView: Bool = false

    // MARK: - Computed Properties
    private var swarmViews: [SwarmSettingView] {
        guard let conversation = viewmodel.conversation, !conversation.isCoredialog() else {
            return [.about]
        }
        return [.about, .memberList]
    }
    
    private var lightOrDarkColor: Color {
        let isLight = Color(hex: viewmodel.finalColor)?.isLight(threshold: 0.8) ?? true
        return isLight ? Color(UIColor.jamiMain) : Color.white
    }
    
    private var placeholderColor: Color {
        if viewmodel.finalColor == "#CDDC39" || viewmodel.finalColor == "#FFC107" {
            return Color.white.opacity(0.7)
        }
        
        let isLight = Color(hex: viewmodel.finalColor)?.isLight(threshold: 0.8) ?? true
        return isLight ? Color.black.opacity(0.5) : Color.white.opacity(0.5)
    }
    
    // MARK: - Body
    public var body: some View {
        ZStack(alignment: .bottomTrailing) {
            mainContent
            colorPickerOverlay
            addParticipantsButton
        }
        .onReceive(orientationPublisher) { _ in
            minimizedTopView = shouldMinimizeTop()
        }
        .onAppear {
            setupInitialState()
        }
        .ignoresSafeArea(edges: [.top])
        .background(Color(UIColor.systemGroupedBackground))
    }
    
    // MARK: - Main Content Components
    
    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: 0) {
            topArea
            segmentedControl
            contentArea
        }
        .onLoad {
            descriptionTextFieldInput = viewmodel.swarmInfo.description.value
            titleTextFieldInput = viewmodel.finalTitle
        }
        .onChange(of: viewmodel.finalTitle) { newValue in
            titleTextFieldInput = newValue
        }
    }
    
    @ViewBuilder
    private var topArea: some View {
        if minimizedTopView {
            minimizedTopBar
        } else {
            fullTopArea
        }
    }
    
    private var minimizedTopBar: some View {
        Color(hex: viewmodel.finalColor)
            .frame(height: Layout.minimizedTopHeight)
            .ignoresSafeArea(edges: [.top, .leading, .trailing])
    }
    
    private var fullTopArea: some View {
        VStack(spacing: Layout.verticalSpacing) {
            HStack {
                Spacer()
                VStack(spacing: Layout.verticalSpacing) {
                    Spacer().frame(height: 30)
                    avatarView
                    titleView
                    descriptionView
                    if viewmodel.getContactJamiId() != nil {
                        callButtons
                    }
                }
                Spacer()
            }
        }
        .padding(Layout.contentPadding)
        .ignoresSafeArea(edges: [.top, .leading, .trailing])
        .background(Color(hex: viewmodel.finalColor))
    }
    
    private var callButtons: some View {
        HStack(spacing: Layout.callButtonSpacing) {
            Spacer()
            
            callButton(
                systemName: "phone",
                action: placeAudioCall,
                accessibilityLabel: "Place audio call"
            )
            
            callButton(
                systemName: "video",
                action: placeVideoCall,
                accessibilityLabel: "Place video call"
            )
            
            Spacer()
        }
        .padding(.vertical, 5)
    }
    
    private func callButton(systemName: String, action: @escaping () -> Void, accessibilityLabel: String) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(lightOrDarkColor)
                .frame(width: Layout.callButtonSize, height: Layout.callButtonSize)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(UIColor.white).opacity(0.2)))
        }
        .accessibilityLabel(accessibilityLabel)
    }
    
    @ViewBuilder
    private var avatarView: some View {
        if viewmodel.isAdmin {
            editableAvatar
        } else {
            nonEditableAvatar
        }
    }
    
    private var editableAvatar: some View {
        Button {
            showingOptions = true
        } label: {
            avatarImage
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
            ImagePicker(
                sourceType: type == .gallery ? .photoLibrary : .camera,
                showingType: $showingType,
                image: $image
            )
        }
        .onChange(of: image) { newValue in
            viewmodel.updateSwarmAvatar(image: newValue)
        }
    }
    
    private var nonEditableAvatar: some View {
        avatarImage
    }
    
    private var avatarImage: some View {
        Image(uiImage: viewmodel.finalAvatar)
            .renderingMode(.original)
            .resizable()
            .scaledToFill()
            .frame(width: Layout.avatarSize, height: Layout.avatarSize, alignment: .center)
            .clipShape(Circle())
    }
    
    @ViewBuilder
    private var titleView: some View {
        if viewmodel.isAdmin {
            titleTextField
        } else {
            titleLabel
        }
    }
    
    @ViewBuilder
    private var descriptionView: some View {
        if viewmodel.isAdmin,
           let conversation = viewmodel.conversation,
           !conversation.isCoredialog() {
            descriptionTextField
                .padding(.bottom, 10)
        } else if !viewmodel.description.isEmpty {
            descriptionLabel
                .padding(.bottom, 10)
        }
    }
    
    @ViewBuilder
    private var segmentedControl: some View {
        if swarmViews.count > 1 {
            Picker("", selection: $selectedView) {
                ForEach(swarmViews, id: \.self) { view in
                    Text(view == .memberList ? 
                         "\(viewmodel.swarmInfo.participants.value.count) \(view.title)" : 
                         view.title)
                }
            }
            .onChange(of: selectedView) { _ in
                viewmodel.showColorSheet = false
            }
            .pickerStyle(.segmented)
            .padding([.horizontal, .top], Layout.segmentedControlPadding)
        }
    }
    
    @ViewBuilder
    private var contentArea: some View {
        switch selectedView {
        case .about:
            SettingsView(viewmodel: viewmodel, stateEmitter: stateEmitter)
        case .memberList:
            MemberList(viewmodel: viewmodel)
        }
    }
    
    @ViewBuilder
    private var colorPickerOverlay: some View {
        if viewmodel.showColorSheet {
            ZStack(alignment: .bottom) {
                Rectangle()
                    .foregroundColor(.black.opacity(0.5))
                    .onTapGesture {
                        dismissColorPicker()
                    }
                    .ignoresSafeArea()
                
                CustomColorPicker(
                    selectedColor: $viewmodel.selectedColor,
                    currentColor: $viewmodel.finalColor
                )
                .frame(height: 70)
                .background(Color.white)
                .onChange(of: viewmodel.finalColor) { _ in
                    dismissColorPicker()
                }
                .ignoresSafeArea()
            }
        }
    }
    
    @ViewBuilder
    private var addParticipantsButton: some View {
        if !(viewmodel.conversation?.isCoredialog() ?? true) {
            AddMoreParticipantsInSwarm(viewmodel: viewmodel)
        }
    }
    
    // MARK: - Text Components
    
    private var titleLabel: some View {
        Text(viewmodel.finalTitle)
            .font(Font.title3.weight(.semibold))
            .multilineTextAlignment(.center)
            .truncationMode(.middle)
            .foregroundColor(lightOrDarkColor)
            .accentColor(lightOrDarkColor)
    }
    
    private var titleTextField: some View {
        TextField(
            "",
            text: $viewmodel.finalTitle,
            onCommit: {
                viewmodel.title = titleTextFieldInput
            })
            .truncationMode(.middle)
            .foregroundColor(lightOrDarkColor)
            .accentColor(lightOrDarkColor)
            .font(Font.title3.weight(.semibold))
            .multilineTextAlignment(.center)
    }
    
    private var descriptionLabel: some View {
        Text(viewmodel.swarmInfo.description.value)
            .font(.body)
            .multilineTextAlignment(.center)
            .foregroundColor(lightOrDarkColor)
            .accentColor(lightOrDarkColor)
    }
    
    private var descriptionTextField: some View {
        TextField(
            "",
            text: $descriptionTextFieldInput,
            onCommit: {
                viewmodel.description = descriptionTextFieldInput
            })
            .placeholder(when: descriptionTextFieldInput.isEmpty) {
                Text(L10n.Swarm.addDescription)
                    .foregroundColor(placeholderColor)
            }
            .accentColor(lightOrDarkColor)
            .foregroundColor(lightOrDarkColor)
            .font(.body)
            .multilineTextAlignment(.center)
    }
    
    // MARK: - Action Methods
    
    private func placeAudioCall() {
        guard let jamiId = viewmodel.getContactJamiId() else { return }
        stateEmitter.emitState(.startAudioCall(contactRingId: jamiId, userName: ""))
    }
    
    private func placeVideoCall() {
        guard let jamiId = viewmodel.getContactJamiId() else { return }
        stateEmitter.emitState(.startCall(contactRingId: jamiId, userName: ""))
    }
    
    // MARK: - Helper Methods
    
    private func setupInitialState() {
        minimizedTopView = shouldMinimizeTop()
        descriptionTextFieldInput = viewmodel.swarmInfo.description.value
        titleTextFieldInput = viewmodel.finalTitle
    }
    
    private func shouldMinimizeTop() -> Bool {
        return UIDevice.current.orientation.isLandscape && 
               UIDevice.current.userInterfaceIdiom == .phone
    }
    
    private func dismissColorPicker() {
        viewmodel.showColorSheet = false
        viewmodel.hideShowBackButton(colorPicker: false)
    }
    
    private var orientationPublisher: NotificationCenter.Publisher {
        NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)
    }
}
