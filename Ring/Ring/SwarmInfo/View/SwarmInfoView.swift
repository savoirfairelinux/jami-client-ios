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
    case documents

    var title: String {
        switch self {
        case .about:
            return L10n.Swarm.settings
        case .memberList:
            return L10n.Swarm.members
        case .documents:
            return L10n.Collab.documents
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
        static let minimumTapSize: CGFloat = 44
        static let avatarTopGap: CGFloat = 14
        static let avatarBottomGap: CGFloat = 12
        static let sectionSpacing: CGFloat = 8
        static let expandAnimation: Animation = .spring(response: 0.38, dampingFraction: 0.9)
        static let floatingButtonClearance: CGFloat = 88
        static let expandedInfoBackdropStrength: CGFloat = 0.9
        static let topChromeSize: CGFloat = 100
        static let topChromeBlurRadius: CGFloat = 4
    }

    // MARK: - Properties
    @ObservedObject var viewModel: SwarmInfoVM
    @ObservedObject private var provider: AvatarProvider
    @ObservedObject private var screen = ScreenDimensionsManager.shared
    let stateEmitter = ConversationStatePublisher()
    let onAvatarExpansionChanged: (Bool) -> Void

    // MARK: - State
    @SwiftUI.State private var selectedView: SwarmSettingView = .about
    @SwiftUI.State private var showingOptions = false
    @SwiftUI.State private var showingType: PhotoSheetType?
    @SwiftUI.State private var image: UIImage?
    @SwiftUI.State private var isAvatarExpanded = false

    init(viewModel: SwarmInfoVM,
         onAvatarExpansionChanged: @escaping (Bool) -> Void = { _ in }) {
        self.viewModel = viewModel
        self.provider = viewModel.provider
        self.onAvatarExpansionChanged = onAvatarExpansionChanged
    }

    // MARK: - Computed Properties
    private var swarmViews: [SwarmSettingView] {
        guard let conversation = viewModel.conversation else { return [.about] }
        var views: [SwarmSettingView] = [.about]
        if !conversation.isCoredialog() {
            views.append(.memberList)
        }
        // A document lives in the conversation's repository, so it exists for
        // every swarm — including a one-to-one one — and for nothing else.
        if conversation.isSwarm() {
            views.append(.documents)
        }
        return views
    }

    private var collapsedTopInset: CGFloat {
        screen.safeAreaInsets.top + Layout.avatarTopGap
    }

    private var segmentedControlHorizontalPadding: CGFloat {
        if #available(iOS 26.0, *) {
            return 0
        }
        return Layout.generalMargin
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

    private var shouldReserveFloatingButtonSpace: Bool {
        switch selectedView {
        case .documents:
            return viewModel.collabDocuments != nil
        case .about, .memberList:
            return !(viewModel.conversation?.isCoredialog() ?? true)
        }
    }

    // MARK: - Body
    public var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color(UIColor.systemGroupedBackground)
            mainContent
            floatingActionButton
            documentNamePrompt
            if viewModel.isShowingTitleAlert {
                editTitleAlert()
            }
            if viewModel.isShowingDescriptionAlert {
                editDescriptionAlert()
            }
        }
        .overlay(alignment: .top) {
            if #unavailable(iOS 26.0), isAvatarExpanded {
                topScreenFade
            }
        }
        .onAppear {
            setAvatarExpanded(viewModel.provider.canExpand,
                              providesFeedback: false,
                              notifiesWhenUnchanged: true)
        }
        .onChange(of: viewModel.provider.canExpand) { canExpand in
            setAvatarExpanded(canExpand, providesFeedback: false)
        }
        .onDisappear(perform: releaseExpandedAvatar)
        .ignoresSafeArea(edges: [.top, .leading, .trailing])
    }

    // MARK: - Main Content Components

    private var mainContent: some View {
        List {
            topArea
            segmentedControlSection
            contentArea
        }
        .adaptiveInsetGroupedListStyle()
        .optionalListSectionSpacing(Layout.sectionSpacing)
        .hidingTopScrollEdgeEffect()
        .ignoresSafeArea(edges: [.top, .leading, .trailing])
        .safeAreaInset(edge: .bottom) {
            floatingButtonClearance
        }
    }

    private var topArea: some View {
        Section {
            fullTopArea
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
        .optionalFullWidthListSection()
    }

    private func setAvatarExpanded(_ expanded: Bool,
                                   providesFeedback: Bool = true,
                                   notifiesWhenUnchanged: Bool = false) {
        guard expanded != isAvatarExpanded else {
            if notifiesWhenUnchanged {
                onAvatarExpansionChanged(expanded)
            }
            return
        }
        if expanded && providesFeedback {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        }
        withAnimation(Layout.expandAnimation) {
            isAvatarExpanded = expanded
        }
        onAvatarExpansionChanged(expanded)
    }

    private func releaseExpandedAvatar() {
        onAvatarExpansionChanged(false)
        viewModel.provider.releaseExpandedAvatar()
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
            Label(accessibilityLabel, systemImage: systemName)
                .labelStyle(.iconOnly)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(buttonTint)
                .frame(width: Layout.callButtonSize, height: Layout.callButtonSize)
                .background(RoundedRectangle(cornerRadius: Layout.verticalMargin).fill(callButtonBackground))
        }
        .buttonStyle(.plain)
    }

    private var avatarView: some View {
        Group {
            if provider.canExpand {
                expandableAvatar
            } else if viewModel.isAdmin {
                editableAvatar
            } else {
                avatarImage
            }
        }
        .confirmationDialog("", isPresented: $showingOptions, titleVisibility: .hidden) {
            Button(L10n.Alerts.profileTakePhoto) {
                showingType = .picture
            }
            Button(L10n.Alerts.profileUploadPhoto) {
                showingType = .gallery
            }
            Button(L10n.Global.cancel, role: .cancel) {}
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

    private var expandableAvatar: some View {
        ExpandableAvatar(
            provider: viewModel.provider,
            isExpanded: isAvatarExpanded,
            isGroup: !(viewModel.conversation?.isCoredialog() ?? true),
            onToggle: { setAvatarExpanded(!isAvatarExpanded) }
        ) {
            scrimmedInfo
        }
        .overlay(alignment: isAvatarExpanded ? .topTrailing : .bottomTrailing) {
            if viewModel.isAdmin {
                editPictureButton.transition(.opacity)
            }
        }
    }

    private var editPictureButton: some View {
        Button(action: showAvatarOptions) {
            Label(L10n.Accessibility.swarmPicturePicker, systemImage: "camera.fill")
                .labelStyle(.iconOnly)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: Layout.editPictureButtonSize, height: Layout.editPictureButtonSize)
                .background(Circle().fill(Color.jami))
                .frame(width: Layout.minimumTapSize, height: Layout.minimumTapSize)
        }
        .buttonStyle(.plain)
        .padding(.top, isAvatarExpanded ? screen.safeAreaInsets.top + Layout.generalMargin : 0)
        .padding(.trailing, isAvatarExpanded ? Layout.generalMargin : 0)
        .accessibilityHint(L10n.Accessibility.profilePicturePickerHint)
    }

    private var editableAvatar: some View {
        Button(action: showAvatarOptions) {
            avatarImage
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.Accessibility.swarmPicturePicker)
        .accessibilityHint(L10n.Accessibility.profilePicturePickerHint)
    }

    private func showAvatarOptions() {
        showingOptions = true
    }

    private var avatarImage: some View {
        AvatarSwiftUIView(source: viewModel.provider)
            .accessibilityHidden(true)
    }

    @ViewBuilder private var titleView: some View {
        if viewModel.isAdmin {
            Button(action: viewModel.presentTitleEditView) {
                titleLabel
            }
            .buttonStyle(.plain)
            .accessibilityHint(L10n.Swarm.editTextHint)
        } else {
            titleLabel
        }
    }

    private var titleLabel: some View {
        Text(viewModel.title)
            .font(.title3.weight(.semibold))
            .multilineTextAlignment(.center)
            .truncationMode(.middle)
            .lineLimit(2)
            .foregroundStyle(headerForeground)
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
        Button(action: viewModel.presentDescriptionEditView) {
            Text(viewModel.description.isEmpty ? L10n.Swarm.addDescription : viewModel.description)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundStyle(headerForeground)
        }
        .buttonStyle(.plain)
        .accessibilityHint(L10n.Swarm.editTextHint)
    }

    private var descriptionLabel: some View {
        Text(viewModel.description)
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .foregroundStyle(headerForeground)
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
                .padding(.horizontal, segmentedControlHorizontalPadding)
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
        case .documents:
            if let documents = viewModel.collabDocuments {
                CollabDocumentsView(viewModel: documents, stateEmitter: stateEmitter)
            }
        }
    }

    /// The prompt for a new document's name belongs over the whole screen, not
    /// over the tab it was asked from, so it is raised here beside the alerts
    /// this screen already shows.
    @ViewBuilder private var documentNamePrompt: some View {
        if selectedView == .documents, let documents = viewModel.collabDocuments {
            CollabNewDocumentPrompt(viewModel: documents, stateEmitter: stateEmitter)
        }
    }

    @ViewBuilder private var floatingActionButton: some View {
        switch selectedView {
        case .documents:
            if let documents = viewModel.collabDocuments {
                CollabNewDocumentButton(viewModel: documents)
            }
        case .about, .memberList:
            if !(viewModel.conversation?.isCoredialog() ?? true) {
                AddMoreParticipantsInSwarm(viewmodel: viewModel)
            }
        }
    }

    @ViewBuilder private var floatingButtonClearance: some View {
        if shouldReserveFloatingButtonSpace {
            Color.clear
                .frame(height: Layout.floatingButtonClearance)
                .accessibilityHidden(true)
        }
    }
}

// MARK: - Expanded Avatar Chrome

private extension SwarmInfoView {
    var scrimmedInfo: some View {
        infoStack
            .padding(Layout.generalMargin)
            .padding(.top, 60)
            .frame(maxWidth: .infinity)
            .background(infoBackdrop)
    }

    var infoBackdrop: some View {
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

    var scrim: Color {
        Color.jamiOnVideoScrim.opacity(Layout.expandedInfoBackdropStrength)
    }

    var topScreenFade: some View {
        let height = screen.safeAreaInsets.top + Layout.topChromeSize
        return
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: scrim, location: 0),
                    .init(color: scrim.opacity(0.55), location: 0.38),
                    .init(color: scrim.opacity(0.18), location: 0.7),
                    .init(color: .clear, location: 1)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: screen.adaptiveWidth, height: height)
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

// MARK: - Alert Components

extension SwarmInfoView {
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
