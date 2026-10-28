/*
 *  Copyright (C) 2022 - 2026 Savoir-faire Linux Inc.
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
import UIKit
import Combine

struct Flipped: ViewModifier {
    func body(content: Content) -> some View {
        content
            .rotationEffect(.radians(Double.pi))
            .scaleEffect(x: -1, y: 1, anchor: .center)
    }
}

extension View {
    func flipped() -> some View {
        modifier(Flipped())
    }
}

struct ScrollViewOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat?

    static func reduce(value: inout CGFloat?, nextValue: () -> CGFloat?) {
        value = value ?? nextValue()
    }
}

struct MessagePanelTopPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat?

    static func reduce(value: inout CGFloat?, nextValue: () -> CGFloat?) {
        value = value ?? nextValue()
    }
}

struct MessagesListView: View {
    @ObservedObject var model: MessagesListVM
    @ObservedObject var callBannerViewModel: CallBannerViewModel
    @SwiftUI.State var showScrollToLatestButton = false
    let scrollReserved = ScreenDimensionsManager.shared.adaptiveHeight * 1.5
    private let messagesUnderPanelOverlap: CGFloat = -30
    private let scrollButtonGap: CGFloat = 8

    // context menu
    @SwiftUI.State var contextMenuPresentingState: ContextMenuPresentingState = .none
    @SwiftUI.State private var currentSnapshot: UIImage?
    @SwiftUI.State private var presentingMessage: MessageBubbleView?
    @SwiftUI.State private var messageFrame: CGRect?
    @SwiftUI.State private var screenHeight: CGFloat = 0
    @SwiftUI.State var isMessageBarFocused: Bool = false
    @SwiftUI.State var keyboardHeight: CGFloat = 0
    @SwiftUI.State private var keyboardWasActiveBeforeMenu: Bool = false

    @ObservedObject private var dimensionsManager = ScreenDimensionsManager.shared

    // reactions
    @SwiftUI.State private var reactionsForMessage: ReactionsContainerModel?
    @SwiftUI.State private var showReactionsView = false

    @SwiftUI.State private var envAppeared = false
    @SwiftUI.State private var isApplicationActive = UIApplication.shared.applicationState == .active

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.sizeCategory) private var sizeCategory

    private let emptyStateSpacing: CGFloat = 16
    private var textHorizontalPadding: CGFloat {
        sizeCategory.isAccessibilityCategory ? 16 : 48
    }

    init(model: MessagesListVM) {
        self.model = model
        self.callBannerViewModel = model.callBannerViewModel
    }

    var body: some View {
        ZStack {
            conversationContentView()
            if showReactionsView {
                if let reactions = reactionsForMessage {
                    ReactionsView(model: reactions)
                        .onTapGesture {
                            self.showReactionsView = false
                            reactionsForMessage = nil
                        }
                }
            }
            if model.isTemporary {
                temporaryConversationView()
            }

            if model.isConversationEnded {
                endedConversationView()
            }
        }
        .background(ConversationColorBackground(color: model.swarmColor))
        .environment(\.avatarProviderFactory, model.makeAvatarFactory() as AvatarProviderFactory?)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            isApplicationActive = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            isApplicationActive = false
        }
        .onChange(of: model.screenTapped, perform: { _ in
            /* We cannot use SwiftUI's onTapGesture here because it would
             interfere with the interactions of the buttons in the player view.
             Instead, we are using UITapGestureRecognizer from UIView.
             */
            if model.screenTapped {
                showReactionsView = false
                reactionsForMessage = nil
                hideKeyboard()
                // reset to inital state
                model.screenTapped = false
            }
        })
    }

    private func conversationContentView() -> some View {
        ZStack(alignment: .top) {
            VStack(spacing: messagesUnderPanelOverlap) {
                ZStack(alignment: .bottomTrailing) {
                    createMessagesStackView()
                        .flipped()
                        .contextMenuActive(contextMenuPresentingState != .none)
                    if !model.atTheBottom {
                        createScrollToBottmView()
                    }
                }
                if !model.isBlocked {
                    MessagePanelView(model: model.messagePanel, voiceRecording: model.voiceRecording, isFocused: $isMessageBarFocused)
                        .background(
                            GeometryReader { proxy in
                                Color.clear.preference(
                                    key: MessagePanelTopPreferenceKey.self,
                                    value: proxy.frame(in: .global).minY
                                )
                            }
                        )
                }
            }
            .background(
                ContextMenuSnapshotWindowCoordinator(
                    snapshot: currentSnapshot,
                    presentingState: contextMenuPresentingState,
                    model: model.contextMenuModel,
                    presentingStateBinding: $contextMenuPresentingState
                )
            )
            .onChange(of: dimensionsManager.adaptiveHeight) { newHeight in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if screenHeight != newHeight && screenHeight != 0 {
                        screenHeight = newHeight
                        contextMenuPresentingState = .dismissed
                    }
                }
            }
            .onAppear(perform: {
                screenHeight = dimensionsManager.adaptiveHeight
            })

            .onChange(of: contextMenuPresentingState, perform: { state in
                contextMenuPresentingStateChanged(state)
            })
            .onReceive(Publishers.keyboardHeight) { height in
                handleKeyboardHeightChange(height)
            }
            if model.shouldShowMap {
                LocationSharingView(model: model)
            }

            if model.isSyncing {
                syncingConversationView()
            }
            if model.isBlocked {
                blockView()
            }

            if callBannerViewModel.isVisible {
                CallBannerView(viewModel: callBannerViewModel)
            }
        }
    }

    private func createMessagesStackView() -> some View {
        ScrollViewReader { scrollView in
            ScrollView(showsIndicators: false) {
                // update scroll offset
                GeometryReader { proxy in
                    let offset = proxy.frame(in: .named("scroll")).minY
                    Color.clear.preference(key: ScrollViewOffsetPreferenceKey.self, value: offset)
                }
                LazyVStack(spacing: 0) {
                    // scroll to the bottom
                    Text("")
                        .id("lastMessage")
                    if !model.typingIndicatorText.isEmpty {
                        TypingIndicatorView(
                            text: model.typingIndicatorText,
                            isApplicationActive: isApplicationActive
                        )
                        .id(model.typingIndicatorText)
                        .transition(.opacity)
                    }
                    // messages
                    ForEach(model.messagesModels) { message in
                        createMessageRowView(for: message)
                            .id(message.id)
                            // lazy loading
                            .onAppear(perform: {
                                if message == self.model.messagesModels.last {
                                    DispatchQueue.global(qos: .background).async {
                                        self.model.loadMore()
                                    }
                                }
                            })
                    }
                    .flipped()
                }
                .listRowBackground(Color.clear)
                .onReceive(model.$scrollToId, perform: { (scrollToId) in
                    guard scrollToId != nil else { return }
                    scrollView.scrollTo("lastMessage")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        model.scrollToId = nil
                    }
                })
                .onReceive(model.$scrollToReplyTarget, perform: { (scrollToReplyTarget) in
                    guard scrollToReplyTarget != nil else { return }
                    scrollView.scrollTo(scrollToReplyTarget)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        model.scrolledToTargetReply()
                    }
                })
            }
            .onPreferenceChange(ScrollViewOffsetPreferenceKey.self) { value in
                DispatchQueue.main.async {
                    let scrollOffset = value ?? 0
                    let atTheBottom = scrollOffset < scrollReserved
                    if atTheBottom != model.atTheBottom {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            model.atTheBottom = atTheBottom
                        }
                    }
                }
            }
        }
    }

    private func createMessageRowView(for message: MessageContainerModel) -> some View {
        MessageRowView(messageModel: message, onLongPress: {(frame, message) in
            if contextMenuPresentingState != .dismissed && contextMenuPresentingState != .none {
                return
            }
            guard let snapshot = captureKeyWindowSnapshot(erasingRect: frame) else { return }
            model.configureContextMenu(with: message, frame: frame)
            currentSnapshot = snapshot
            contextMenuPresentingState = .shouldPresent

            if keyboardHeight > 0 {
                keyboardWasActiveBeforeMenu = true
                isMessageBarFocused = false
                DispatchQueue.main.async {
                    UIView.performWithoutAnimation {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
        }, showReactionsView: {message in
            reactionsForMessage = message
            showReactionsView.toggle()
        }, model: message.messageRow)
    }

    func createScrollToBottmView() -> some View {
        ScrollToLatestButton(newMessagesCount: model.numberOfNewMessages, conversationColor: model.swarmColor) {
            model.scrollToTheBottom()
        }
        .padding(.trailing, MessagePanelView.horizontalInset - ScrollToLatestButton.visualInset)
        .padding(.bottom, -messagesUnderPanelOverlap - MessagePanelView.verticalInset + scrollButtonGap - ScrollToLatestButton.visualInset)
        .transition(.opacity)
    }

    private func temporaryConversationView() -> some View {
        TemporaryConversationView(model: model, envAppeared: $envAppeared)
    }

    func endedConversationView() -> some View {
        EndedConversationView()
    }

    private func syncingConversationView() -> some View {
        SyncingConversationView(model: model, isApplicationActive: isApplicationActive)
    }

    func blockView() -> some View {
        BlockView(model: model)
    }

    private func handleKeyboardHeightChange(_ height: CGFloat) {
        DispatchQueue.main.async {
            keyboardHeight = height
        }
    }

    private func contextMenuPresentingStateChanged(_ state: ContextMenuPresentingState) {
        /*
         When the context menu is removed, we need to reopen
         the keyboard and reactivate the message bar if it was
         active before, except in cases where a selected action
         will trigger the keyboard itself. For example, actions
         like editing or replying to a message.
         */
        switch state {
        case .willDismissWithoutAction, .willDismissWithAction:
            if keyboardWasActiveBeforeMenu {
                isMessageBarFocused = true
                keyboardWasActiveBeforeMenu = false
            }
        case .willDismissWithTextEditingAction:
            keyboardWasActiveBeforeMenu = false
        case .dismissed:
            keyboardWasActiveBeforeMenu = false
            currentSnapshot = nil
            DispatchQueue.main.async {
                contextMenuPresentingState = .none
            }
        case .none, .shouldPresent:
            break
        }
    }
}

// MARK: - Extracted Subviews

private struct ConversationColorBackground: View {
    private struct Glow {
        let hueShift: CGFloat
        let peakOpacity: Double
        let center: UnitPoint
        let radiusScale: CGFloat
    }

    private static let glows = [
        Glow(hueShift: 0, peakOpacity: 0.1, center: UnitPoint(x: 0.15, y: 0.08), radiusScale: 0.85),
        Glow(hueShift: 60, peakOpacity: 0.08, center: UnitPoint(x: 0.92, y: 0.35), radiusScale: 0.77),
        Glow(hueShift: -60, peakOpacity: 0.07, center: UnitPoint(x: 0.25, y: 0.92), radiusScale: 0.85)
    ]

    private static let neutralChromaLimit: CGFloat = 0.08
    private static let darkestNeutralOnLight: CGFloat = 0.45
    private static let lightestNeutralOnDark: CGFloat = 0.88

    private static let falloffLocations: [Double] = [0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875, 1]

    let color: UIColor

    @Environment(\.colorScheme)
    private var colorScheme

    private var drawsGlow: Bool {
        guard let oklab = OklabColor(color), oklab.chroma < Self.neutralChromaLimit else { return true }
        return colorScheme == .dark
            ? oklab.lightness <= Self.lightestNeutralOnDark
            : oklab.lightness >= Self.darkestNeutralOnLight
    }

    var body: some View {
        GeometryReader { proxy in
            let extent = max(proxy.size.width, proxy.size.height)
            ZStack {
                Color(UIColor.systemBackground)
                if drawsGlow {
                    ForEach(Self.glows.indices, id: \.self) { index in
                        gradient(for: Self.glows[index], extent: extent)
                    }
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private static func falloff(at distance: Double) -> Double {
        pow(1 - distance * distance, 2)
    }

    private func gradient(for glow: Glow, extent: CGFloat) -> some View {
        let glowColor = Color(color.rotatingHue(by: glow.hueShift))
        return RadialGradient(stops: Self.falloffLocations.map { location in
                                  Gradient.Stop(color: glowColor.opacity(glow.peakOpacity * Self.falloff(at: location)),
                                                location: CGFloat(location))
                              },
                              center: glow.center,
                              startRadius: 0,
                              endRadius: extent * glow.radiusScale)
    }
}

private struct TypingIndicatorView: View {
    private static let animationInterval: TimeInterval = 0.5

    let text: String
    let isApplicationActive: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: Self.animationInterval, paused: !isApplicationActive)) { context in
            let dotCount = Int(context.date.timeIntervalSinceReferenceDate / Self.animationInterval) % 4
            HStack {
                Text("\(text)\(String(repeating: ".", count: dotCount))")
                    .font(.footnote)
                    .foregroundColor(.conversationSecondaryText)
                Spacer()
            }
        }
        .flipped()
        .padding(.horizontal)
        .padding(.vertical, 5)
        .accessibilityElement()
        .accessibilityLabel(text)
    }
}

private struct TemporaryConversationView: View {
    @ObservedObject var model: MessagesListVM
    @Binding var envAppeared: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.sizeCategory) private var sizeCategory

    private let emptyStateSpacing: CGFloat = 16
    private var textHorizontalPadding: CGFloat {
        sizeCategory.isAccessibilityCategory ? 16 : 48
    }

    var body: some View {
        let buttonIconSpacing: CGFloat = 6
        let buttonIconSize: CGFloat = 18
        let buttonVPadding: CGFloat = 10
        let factory = model.makeAvatarFactory()
        ZStack {
            ConversationColorBackground(color: model.swarmColor)
            VStack(spacing: emptyStateSpacing) {
                Spacer()
                Group {
                    if let jamiId = model.firstParticipantJamiId {
                        AvatarSwiftUIView(source: factory.provider(for: jamiId, size: .conversationInfo80))
                            .accessibilityHidden(true)
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(Color.jami)
                            .accessibilityHidden(true)
                    }
                }
                .scaleEffect(envAppeared ? 1.0 : 0.85)
                .opacity(envAppeared ? 1.0 : 0.0)
                .onAppear {
                    if reduceMotion {
                        envAppeared = true
                    } else {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
                            envAppeared = true
                        }
                    }
                }
                .onDisappear {
                    envAppeared = false
                }
                Text(L10n.Conversation.notContactLabel(model.displayNameForTemporary))
                    .font(.footnote)
                    .foregroundColor(Color(UIColor.secondaryLabel))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, textHorizontalPadding)
                Button(action: {
                    model.sendRequest()
                }, label: {
                    HStack(spacing: buttonIconSpacing) {
                        Image(systemName: "paperplane.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: buttonIconSize, height: buttonIconSize)
                            .foregroundColor(.jami)
                            .accessibilityHidden(true)
                        Text(L10n.Conversation.sendInvitationButton)
                            .font(.callout)
                            .foregroundColor(Color(UIColor.label))
                    }
                    .padding(.horizontal)
                    .padding(.vertical, buttonVPadding)
                    .frame(maxWidth: .infinity)
                    .background(Color.jamiTertiaryControl)
                    .cornerRadius(12)
                })
                .accessibilityIdentifier(ConversationAccessibilityIdentifiers.sendInvitationButton)
                .padding(.horizontal, textHorizontalPadding)
                Spacer()
                Spacer()
            }
        }
        .contentShape(Rectangle())
    }
}

private struct EndedConversationView: View {
    var body: some View {
        VStack {
            VStack {
                Text(L10n.Swarm.conversationEnded)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            Spacer()
        }
    }
}

private struct SyncingConversationView: View {
    private static let animationInterval: TimeInterval = 0.5

    @ObservedObject var model: MessagesListVM
    let isApplicationActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.sizeCategory) private var sizeCategory

    private let emptyStateSpacing: CGFloat = 16
    private var textHorizontalPadding: CGFloat {
        sizeCategory.isAccessibilityCategory ? 16 : 48
    }

    var body: some View {
        let textSpacing: CGFloat = 7
        let dotSize: CGFloat = 7
        let dotSpacing: CGFloat = 6
        let dotsPadding: CGFloat = 4
        let dotOpacities: [Double] = [1.0, 0.55, 0.25]
        VStack(spacing: emptyStateSpacing) {
            Spacer()
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 40))
                .foregroundColor(Color.jami)
                .accessibilityHidden(true)
            VStack(spacing: textSpacing) {
                Text(L10n.Conversation.syncingTitle)
                    .font(.body.weight(.semibold))
                    .foregroundColor(Color(UIColor.label))
                Text(model.syncMessage)
                    .font(.footnote)
                    .foregroundColor(Color(UIColor.secondaryLabel))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, textHorizontalPadding)
            TimelineView(
                .animation(
                    minimumInterval: Self.animationInterval,
                    paused: !isApplicationActive || reduceMotion
                )
            ) { context in
                let syncPhase = Int(context.date.timeIntervalSinceReferenceDate / Self.animationInterval) % 3
                HStack(spacing: dotSpacing) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(Color.jami)
                            .frame(width: dotSize, height: dotSize)
                            .opacity(reduceMotion ? 1.0 : dotOpacities[(index - syncPhase + 3) % 3])
                            .animation(reduceMotion ? nil : .easeInOut(duration: 0.4), value: syncPhase)
                    }
                }
            }
            .accessibilityHidden(true)
            .padding(.top, dotsPadding)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ConversationColorBackground(color: model.swarmColor))
        .contentShape(Rectangle())
    }
}

private struct BlockView: View {
    @ObservedObject var model: MessagesListVM

    var body: some View {
        VStack {
            Text(L10n.Conversation.contactBlocked)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
            Button(action: {
                model.unblock()
            }, label: {
                HStack {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 18, height: 18)
                        .foregroundColor(.jami)
                    Text(L10n.AccountPage.unblockContact)
                        .foregroundColor(Color(UIColor.label))
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(Color.jamiTertiaryControl)
                .cornerRadius(12)
            })
        }
        .padding()
        .background(VisualEffect(style: .systemChromeMaterial, withVibrancy: false).allowsHitTesting(false))
        .background(VisualEffect(style: .systemThickMaterial, withVibrancy: true).allowsHitTesting(false))
    }
}

func topVC() -> UIViewController? {
    let keyWindow = UIApplication.shared.windows.filter { $0.isKeyWindow }.first

    if var topController = keyWindow?.rootViewController {
        while let presentedViewController = topController.presentedViewController {
            topController = presentedViewController
        }

        if UIDevice.current.userInterfaceIdiom == .pad {
            let children = topController.children
            if !children.isEmpty {
                let splitVC = children[0]
                let sideVCs = splitVC.children
                if sideVCs.count > 1 {
                    topController = sideVCs[1]
                    return topController
                }
            }
        }

        return topController
    }

    return nil
}

struct ScrollToLatestButton: View {
    static let tapTargetSize: CGFloat = 44
    private static let circleSize: CGFloat = 40
    static let visualInset: CGFloat = (tapTargetSize - circleSize) / 2

    let newMessagesCount: Int
    let conversationColor: UIColor
    let action: () -> Void

    private let chevronSize: CGFloat = 17
    private let badgeOffset: CGFloat = 6
    private let badgeMinSize: CGFloat = 18
    private let badgeHorizontalPadding: CGFloat = 5

    private var palette: UIColor.MessageBubblePalette {
        .palette(for: conversationColor)
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.down")
                .font(.system(size: chevronSize, weight: .medium))
                .foregroundColor(Color(palette.receivedControl))
                .frame(width: Self.circleSize, height: Self.circleSize)
                .conversationControlGlass(in: Circle())
                .overlay(alignment: .topTrailing) {
                    if newMessagesCount > 0 {
                        badge
                            .offset(x: badgeOffset, y: -badgeOffset)
                    }
                }
                .frame(width: Self.tapTargetSize, height: Self.tapTargetSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.Accessibility.scrollToLatestMessage)
        .accessibilityValue(newMessagesCount > 0 ? L10n.Accessibility.newMessagesCount(newMessagesCount) : "")
    }

    private var badge: some View {
        Text(verbatim: String(newMessagesCount))
            .font(Font.caption2.weight(.semibold).monospacedDigit())
            .foregroundColor(Color(palette.sentText))
            .padding(.horizontal, badgeHorizontalPadding)
            .frame(minWidth: badgeMinSize, minHeight: badgeMinSize)
            .background(Capsule().fill(Color(palette.sentBackground)))
    }
}
