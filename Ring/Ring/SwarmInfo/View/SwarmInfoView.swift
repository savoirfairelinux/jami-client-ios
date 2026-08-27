/*
 * Copyright (C) 2022-2026 Savoir-faire Linux Inc. *
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

enum SwarmProfileAction: Hashable {
    case audioCall
    case videoCall
    case editProfile

    static func available(canCall: Bool, canEdit: Bool) -> [SwarmProfileAction] {
        var actions: [SwarmProfileAction] = canCall ? [.audioCall, .videoCall] : []
        if canEdit {
            actions.append(.editProfile)
        }
        return actions
    }

    var title: String {
        switch self {
        case .audioCall: return L10n.Global.call
        case .videoCall: return L10n.Global.video
        case .editProfile: return L10n.Global.edit
        }
    }

    var systemImage: String {
        switch self {
        case .audioCall: return "phone.fill"
        case .videoCall: return "video.fill"
        case .editProfile: return "square.and.pencil"
        }
    }

    func accessibilityLabel(for profileName: String, isGroup: Bool) -> String {
        switch self {
        case .audioCall:
            return L10n.Accessibility.conversationStartVoiceCall(profileName)
        case .videoCall:
            return L10n.Accessibility.conversationStartVideoCall(profileName)
        case .editProfile:
            return isGroup ? L10n.ProfileEditor.editGroup : L10n.ProfileEditor.editContact
        }
    }

    func accessibilityHint(isGroup: Bool) -> String {
        switch self {
        case .audioCall, .videoCall:
            return ""
        case .editProfile:
            return isGroup ? L10n.ProfileEditor.editGroupHint : L10n.ProfileEditor.editContactHint
        }
    }
}

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
            titleLabel
            descriptionView
            if !profileActions.isEmpty {
                profileActionButtons
            }
        }
    }

    private var profileActions: [SwarmProfileAction] {
        SwarmProfileAction.available(canCall: viewModel.callTarget != nil,
                                     canEdit: viewModel.canEditProfile)
    }

    private var profileActionButtons: some View {
        HStack(spacing: Layout.generalMargin) {
            ForEach(profileActions, id: \.self) { action in
                profileActionButton(action)
            }
        }
        .padding(.top, Layout.callButtonsMargin)
    }

    private func profileActionButton(_ action: SwarmProfileAction) -> some View {
        Button(action: { perform(action) }) {
            VStack(spacing: Layout.callButtonsMargin) {
                Image(systemName: action.systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(buttonTint)
                    .frame(width: Layout.callButtonSize, height: Layout.callButtonSize)
                    .background(RoundedRectangle(cornerRadius: Layout.verticalMargin).fill(callButtonBackground))

                Text(action.title)
                    .font(.caption)
                    .foregroundStyle(headerForeground)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(action.accessibilityLabel(for: viewModel.title,
                                                      isGroup: viewModel.isGroupProfile))
        .accessibilityHint(action.accessibilityHint(isGroup: viewModel.isGroupProfile))
    }

    private func perform(_ action: SwarmProfileAction) {
        switch action {
        case .audioCall:
            placeAudioCall()
        case .videoCall:
            placeVideoCall()
        case .editProfile:
            editProfile()
        }
    }

    private var avatarView: some View {
        Group {
            if provider.canExpand {
                expandableAvatar
            } else {
                avatarImage
            }
        }
    }

    private var expandableAvatar: some View {
        ExpandableAvatar(
            provider: viewModel.provider,
            isExpanded: isAvatarExpanded,
            isGroup: viewModel.isGroupProfile,
            onToggle: { setAvatarExpanded(!isAvatarExpanded) }
        ) {
            scrimmedInfo
        }
    }

    private var avatarImage: some View {
        AvatarSwiftUIView(source: viewModel.provider)
            .accessibilityHidden(true)
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

    private var displayedDescription: String {
        viewModel.description.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @ViewBuilder private var descriptionView: some View {
        if !displayedDescription.isEmpty {
            descriptionLabel
                .padding(.bottom, Layout.verticalMargin)
        }
    }

    private var descriptionLabel: some View {
        Text(displayedDescription)
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .foregroundStyle(headerForeground)
            .accessibilityLabel(displayedDescription)
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

// MARK: - Actions

extension SwarmInfoView {
    private func editProfile() {
        viewModel.editProfile(stateEmitter: stateEmitter)
    }

    private func placeAudioCall() {
        guard let target = viewModel.callTarget else { return }
        stateEmitter.emitState(.startAudioCall(contactRingId: target.uri,
                                               userName: target.displayName))
    }

    private func placeVideoCall() {
        guard let target = viewModel.callTarget else { return }
        stateEmitter.emitState(.startCall(contactRingId: target.uri,
                                          userName: target.displayName))
    }
}
