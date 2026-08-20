/*
 * Copyright (C) 2022-2025 Savoir-faire Linux Inc. *
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

// MARK: - Enums and Types

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
    enum Layout {
        static let verticalMargin: CGFloat = 10
        static let generalMargin: CGFloat = 20
        static let callButtonSize: CGFloat = 45
        static let callButtonsMargin: CGFloat = 5
        static let editPictureButtonSize: CGFloat = 32
        static let avatarTopGap: CGFloat = 4
        static let avatarBottomGap: CGFloat = 12
        static let scrollSpace = "swarmInfoScroll"
        static let expandThreshold: CGFloat = 110
        static let expandAnimation: Animation = .spring(response: 0.38, dampingFraction: 0.9)
    }

    // MARK: - Properties
    @ObservedObject var viewModel: SwarmInfoVM
    @ObservedObject private var screen = ScreenDimensionsManager.shared
    let stateEmitter = ConversationStatePublisher()
    var onAvatarExpansionChanged: ((Bool) -> Void)?

    // MARK: - State
    @SwiftUI.State private var selectedView: SwarmSettingView = .about
    @SwiftUI.State private var showingOptions = false
    @SwiftUI.State private var showingType: PhotoSheetType?
    @SwiftUI.State private var image: UIImage?
    @SwiftUI.State private var isAvatarExpanded: Bool = false
    @SwiftUI.State private var topSafeArea: CGFloat = 0

    // MARK: - Computed Properties
    private var swarmViews: [SwarmSettingView] {
        guard let conversation = viewModel.conversation, !conversation.isCoredialog() else {
            return [.about]
        }
        return [.about, .memberList]
    }

    private var collapsedTopInset: CGFloat {
        topSafeArea + Layout.avatarTopGap
    }

    private var headerForeground: Color {
        isAvatarExpanded ? .white : Color(UIColor.label)
    }

    private var buttonTint: Color {
        isAvatarExpanded ? .white : Color.jami
    }

    private var callButtonBackground: Color {
        isAvatarExpanded ? Color.white.opacity(0.2) : Color(UIColor.secondarySystemGroupedBackground)
    }

    // MARK: - Body
    public var body: some View {
        GeometryReader { proxy in
            content
                .onAppear { topSafeArea = proxy.safeAreaInsets.top }
                .onChange(of: proxy.safeAreaInsets.top) { topSafeArea = $0 }
        }
    }

    private var content: some View {
        ZStack(alignment: .bottomTrailing) {
            Color(UIColor.systemGroupedBackground)
            mainContent
            addParticipantsButton
            if viewModel.isShowingTitleAlert {
                editTitleAlert()
            }
            if viewModel.isShowingDescriptionAlert {
                editDescriptionAlert()
            }
        }
        .onChange(of: isAvatarExpanded) { expanded in
            onAvatarExpansionChanged?(expanded)
        }
        .onChange(of: viewModel.hasPicture) { hasPicture in
            if !hasPicture {
                setAvatarExpanded(false)
            }
        }
        .ignoresSafeArea(edges: [.top, .leading, .trailing])
    }

    // MARK: - Main Content Components

    private var mainContent: some View {
        List {
            topArea
            segmentedControlSection
            contentArea
        }
        .listStyle(.plain)
        .coordinateSpace(name: Layout.scrollSpace)
        .ignoresSafeArea(edges: [.top, .leading, .trailing])
        .onPreferenceChange(ScrollViewOffsetPreferenceKey.self) { offset in
            respondToScroll(offset)
        }
    }

    private var topArea: some View {
        Section {
            fullTopArea
                .background(scrollOffsetReader)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
    }

    private var scrollOffsetReader: some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: ScrollViewOffsetPreferenceKey.self,
                value: proxy.frame(in: .named(Layout.scrollSpace)).minY
            )
        }
    }

    private func respondToScroll(_ offset: CGFloat?) {
        guard let offset = offset, viewModel.hasPicture else { return }
        if offset > Layout.expandThreshold {
            setAvatarExpanded(true)
        }
    }

    private func setAvatarExpanded(_ expanded: Bool) {
        guard expanded != isAvatarExpanded else { return }
        if expanded {
            viewModel.provider.loadExpandedAvatar(maxPixels: expandedAvatarPixels)
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        }
        withAnimation(Layout.expandAnimation) {
            isAvatarExpanded = expanded
        }
    }

    private var expandedAvatarPixels: CGFloat {
        ExpandedAvatarMetrics.decodePixels(width: screen.adaptiveWidth, height: screen.adaptiveHeight)
    }

    private var fullTopArea: some View {
        VStack(spacing: Layout.avatarBottomGap) {
            avatarView
            if !isAvatarExpanded {
                infoStack
                    .padding(.horizontal, Layout.generalMargin)
                    .transition(.opacity)
            }
        }
        .padding(.top, isAvatarExpanded ? 0 : collapsedTopInset)
        .padding(.bottom, isAvatarExpanded ? 0 : Layout.verticalMargin)
        .frame(maxWidth: .infinity)
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
            viewModel.updateSwarmAvatar(image: newValue)
        }
    }

    private var infoStack: some View {
        VStack(spacing: Layout.generalMargin) {
            titleView
            descriptionView
            if viewModel.getContactJamiId() != nil {
                callButtons
            }
        }
    }

    private var scrimmedInfo: some View {
        infoStack
            .padding(Layout.generalMargin)
            .frame(maxWidth: .infinity)
            .background(infoBackdrop)
    }

    private var infoBackdrop: some View {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: scrim.opacity(0.18), location: 0.3),
                .init(color: scrim.opacity(0.55), location: 0.62),
                .init(color: scrim, location: 1)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .allowsHitTesting(false)
    }

    private var scrim: Color {
        Color.jamiOnVideoScrim.opacity(ExpandedAvatarMetrics.infoBackdropStrength)
    }

    private var callButtons: some View {
        HStack(spacing: Layout.generalMargin) {
            callButton(
                systemName: "phone.fill",
                action: placeAudioCall,
                accessibilityLabel: L10n.Accessibility.conversationStartVoiceCall(viewModel.getContactDisplayName())
            )

            callButton(
                systemName: "video.fill",
                action: placeVideoCall,
                accessibilityLabel: L10n.Accessibility.conversationStartVideoCall(viewModel.getContactDisplayName())
            )
        }
        .padding(.top, Layout.callButtonsMargin)
    }

    private func callButton(systemName: String,
                            action: @escaping () -> Void,
                            accessibilityLabel: String) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(buttonTint)
                .frame(width: Layout.callButtonSize, height: Layout.callButtonSize)
                .background(RoundedRectangle(cornerRadius: Layout.verticalMargin).fill(callButtonBackground))
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder private var avatarView: some View {
        if viewModel.hasPicture {
            expandableAvatar
        } else if viewModel.isAdmin {
            editableAvatar
        } else {
            avatarImage
        }
    }

    private var expandableAvatar: some View {
        ExpandableAvatar(
            provider: viewModel.provider,
            isExpanded: isAvatarExpanded,
            isGroup: !(viewModel.conversation?.isCoredialog() ?? true),
            onToggle: { setAvatarExpanded(!isAvatarExpanded) }
        ) {
            scrimmedInfo
        }
        .overlay(alignment: .topTrailing) {
            if viewModel.isAdmin && isAvatarExpanded {
                editPictureButton.transition(.opacity)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if viewModel.isAdmin && !isAvatarExpanded {
                editPictureButton.transition(.opacity)
            }
        }
    }

    private var editPictureButton: some View {
        Button {
            showingOptions = true
        } label: {
            Image(systemName: "camera.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Color.white)
                .frame(width: Layout.editPictureButtonSize, height: Layout.editPictureButtonSize)
                .background(Circle().fill(Color.jami))
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.top, isAvatarExpanded ? topSafeArea + Layout.generalMargin : 0)
        .padding(.trailing, isAvatarExpanded ? Layout.generalMargin : 0)
        .accessibilityLabel(L10n.Accessibility.swarmPicturePicker)
        .accessibilityHint(L10n.Accessibility.profilePicturePickerHint)
    }

    private var editableAvatar: some View {
        Button {
            showingOptions = true
        } label: {
            avatarImage
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(L10n.Accessibility.swarmPicturePicker)
        .accessibilityHint(L10n.Accessibility.profilePicturePickerHint)
    }

    private var avatarImage: some View {
        AvatarSwiftUIView(source: viewModel.provider)
            .accessibilityHidden(true)
    }

    @ViewBuilder private var titleView: some View {
        if viewModel.isAdmin {
            titleLabel
                .onTapGesture {
                    viewModel.presentTitleEditView()
                }
                .accessibilityHint(L10n.Swarm.editTextHint)
        } else {
            titleLabel
        }
    }

    private var titleLabel: some View {
        Text(viewModel.title)
            .font(Font.title3.weight(.semibold))
            .multilineTextAlignment(.center)
            .truncationMode(.middle)
            .lineLimit(2)
            .foregroundColor(headerForeground)
            .accentColor(headerForeground)
            .accessibilityLabel(viewModel.title)
    }

    @ViewBuilder private var descriptionView: some View {
        if viewModel.isAdmin {
            editableDescriptionText
                .padding(.bottom, Layout.verticalMargin)
        } else if !viewModel.description.isEmpty {
            descriptionLabel
                .padding(.bottom, Layout.verticalMargin)
        }
    }

    private var editableDescriptionText: some View {
        Text(viewModel.description.isEmpty ? L10n.Swarm.addDescription : viewModel.description)
            .onTapGesture {
                viewModel.presentDescriptionEditView()
            }
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .foregroundColor(headerForeground)
            .accentColor(headerForeground)
            .accessibilityLabel(viewModel.description.isEmpty ? L10n.Swarm.addDescription : viewModel.description)
            .accessibilityHint(L10n.Swarm.editTextHint)
    }

    private var descriptionLabel: some View {
        Text(viewModel.description)
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .foregroundColor(headerForeground)
            .accentColor(headerForeground)
            .accessibilityLabel(viewModel.description)
    }

    @ViewBuilder private var segmentedControlSection: some View {
        if swarmViews.count > 1 {
            Section {
                Picker("", selection: $selectedView) {
                    ForEach(swarmViews, id: \.self) { view in
                        Text(view == .memberList ?
                                "\(viewModel.swarmInfo.participants.value.count) \(view.title)" :
                                view.title)
                    }
                }
                .pickerStyle(.segmented)
                .padding([.horizontal, .top], Layout.generalMargin)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
    }

    @ViewBuilder private var contentArea: some View {
        switch selectedView {
        case .about:
            SettingsView(viewmodel: viewModel, stateEmitter: stateEmitter)
        case .memberList:
            MemberList(viewModel: viewModel)
        }
    }

    @ViewBuilder private var addParticipantsButton: some View {
        if !(viewModel.conversation?.isCoredialog() ?? true) {
            AddMoreParticipantsInSwarm(viewmodel: viewModel)
        }
    }

    // MARK: - Alert Components

    @ViewBuilder
    func editTitleAlert() -> some View {
        textInputAlert(
            headerText: L10n.Swarm.titleAlertHeader,
            placeholder: L10n.Swarm.titlePlaceholder,
            text: $viewModel.editableTitle,
            isShowing: $viewModel.isShowingTitleAlert,
            onSave: { viewModel.saveTitle() }
        )
    }

    @ViewBuilder
    func editDescriptionAlert() -> some View {
        textInputAlert(
            headerText: L10n.Swarm.descriptionAlertHeader,
            placeholder: L10n.Swarm.descriptionPlaceholder,
            text: $viewModel.editableDescription,
            isShowing: $viewModel.isShowingDescriptionAlert,
            onSave: { viewModel.saveDescription() }
        )
    }

    @ViewBuilder
    func textInputAlert(
        headerText: String,
        placeholder: String,
        text: Binding<String>,
        isShowing: Binding<Bool>,
        onSave: @escaping () -> Void
    ) -> some View {
        CustomAlert(content: {
            VStack(spacing: 20) {
                Text(headerText)
                    .font(.headline)
                TextField(placeholder, text: text)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                HStack {
                    Button(action: {
                        isShowing.wrappedValue = false
                    }, label: {
                        Text(L10n.Global.cancel)
                            .foregroundColor(.jami)
                    })

                    Spacer()

                    Button(action: {
                        onSave()
                    }, label: {
                        Text(L10n.Global.save)
                            .foregroundColor(.jami)
                    })
                }
            }
        })
    }

    // MARK: - Actions

    private func placeAudioCall() {
        guard let jamiId = viewModel.getContactJamiId() else { return }
        let name = viewModel.getContactDisplayName()
        stateEmitter.emitState(.startAudioCall(contactRingId: jamiId, userName: name))
    }

    private func placeVideoCall() {
        guard let jamiId = viewModel.getContactJamiId() else { return }
        let name = viewModel.getContactDisplayName()
        stateEmitter.emitState(.startCall(contactRingId: jamiId, userName: name))
    }

}
