/*
 *  Copyright (C) 2022 - 2025 Savoir-faire Linux Inc.
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
        let next = nextValue()
        value = next ?? value
    }
}

struct MessagesListView: View {
    @ObservedObject var model: MessagesListVM
    @ObservedObject var callBannerViewModel: CallBannerViewModel
    @SwiftUI.State var showScrollToLatestButton = false
    let scrollReserved = ScreenDimensionsManager.shared.adaptiveHeight * 1.5

    // context menu
    @SwiftUI.State var contextMenuPresentingState: ContextMenuPresentingState = .none
    @SwiftUI.State private var currentSnapshot: UIImage?
    @SwiftUI.State private var presentingMessage: MessageBubbleView?
    @SwiftUI.State private var messageFrame: CGRect?
    @SwiftUI.State private var screenHeight: CGFloat = 0
    @SwiftUI.State private var messageContainerHeight: CGFloat = 0
    @SwiftUI.State private var shouldHideActiveKeyboard = false
    @SwiftUI.State var isMessageBarFocused: Bool = false
    @SwiftUI.State var keyboardHeight: CGFloat = 0

    @ObservedObject private var dimensionsManager = ScreenDimensionsManager.shared

    // reactions
    @SwiftUI.State private var reactionsForMessage: ReactionsContainerModel?
    @SwiftUI.State private var showReactionsView = false

    @SwiftUI.State private var dotCount = 0
    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    init(model: MessagesListVM) {
        self.model = model
        self.callBannerViewModel = model.callBannerViewModel
    }

    var body: some View {
        ZStack {
            ZStack(alignment: .top) {
                ZStack(alignment: .bottom) {
                    ZStack(alignment: .bottomTrailing) {
                        createMessagesStackView()
                            .flipped()
                        if !model.atTheBottom {
                            createScrollToBottmView()
                        }
                    }
                    .layoutPriority(1)
                    .padding(.bottom, shouldHideActiveKeyboard ? keyboardHeight : messageContainerHeight - 30)
                    if !model.isBlocked {
                        MessagePanelView(model: model.messagePanel, isFocused: $isMessageBarFocused)
                            .alignmentGuide(VerticalAlignment.center) { dimensions in
                                DispatchQueue.main.async {
                                    self.messageContainerHeight = dimensions.height
                                }
                                return dimensions[VerticalAlignment.center]
                            }
                    }
                }
                .overlay(contextMenuPresentingState == .shouldPresent && model.contextMenuModel.presentingMessage != nil ? makeOverlay() : nil)
                // hide navigation bar when presenting context menu
                .onChange(of: contextMenuPresentingState) { newValue in
                    let shouldHide = newValue == .shouldPresent
                    model.hideNavigationBar.accept(shouldHide)
                }
                // hide context menu overly when device is rotated
                .onChange(of: dimensionsManager.adaptiveHeight) { newHeight in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        if screenHeight != newHeight && screenHeight != 0 {
                            screenHeight = newHeight
                            contextMenuPresentingState = .dismissed
                            self.shouldHideActiveKeyboard = false
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
                    syncView()
                }

                if model.isBlocked {
                    blockView()
                }

                if callBannerViewModel.isVisible {
                    CallBannerView(viewModel: callBannerViewModel)
                }
            }
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
        }
        .environment(\.avatarProviderFactory, model.makeAvatarFactory() as AvatarProviderFactory?)
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

    func makeOverlay() -> some View {
        return ContextMenuView(model: model.contextMenuModel, presentingState: $contextMenuPresentingState)
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
                        HStack {
                            Text("\(model.typingIndicatorText)\(String(repeating: ".", count: dotCount))")
                                .font(.footnote)
                                .foregroundColor(Color(UIColor.secondaryLabel))
                            Spacer()
                        }
                        .flipped()
                        .padding(.horizontal)
                        .padding(.vertical, 5)
                        .accessibilityElement()
                        .accessibilityLabel("\(model.typingIndicatorText)")
                        .id(model.typingIndicatorText)
                        .transition(.opacity)
                        .onReceive(timer) { _ in
                            dotCount = (dotCount + 1) % 4
                        }
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
                    DispatchQueue.main.async {
                        withAnimation(.easeOut) {
                            scrollView.scrollTo("lastMessage", anchor: .bottom)
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            model.scrollToId = nil
                        }
                    }
                })
                .onReceive(model.$scrollToReplyTarget, perform: { (scrollToReplyTarget) in
                    guard scrollToReplyTarget != nil else { return }
                    DispatchQueue.main.async {
                        withAnimation {
                            scrollView.scrollTo(scrollToReplyTarget, anchor: .center)
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            model.scrolledToTargetReply()
                        }
                    }
                })
                .onAppear {
                    // Initial position at bottom without animation
                    DispatchQueue.main.async {
                        scrollView.scrollTo("lastMessage", anchor: .bottom)
                    }
                }
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ScrollViewOffsetPreferenceKey.self) { value in
                DispatchQueue.main.async {
                    let scrollOffset = value ?? 0
                    let atTheBottom = scrollOffset < scrollReserved
                    if atTheBottom != model.atTheBottom {
                        withAnimation {
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
            model.hideNavigationBar.accept(true)
            model.contextMenuModel.presentingMessage = message
            model.contextMenuModel.messageFrame = frame
            /*
             If the keyboard is open, it should be closed.
             Once the context menu is removed, the keyboard
             should be shown again.
             */
            if keyboardHeight > 0 {
                hideKeyboardIfNeed()
            }
            contextMenuPresentingState = .shouldPresent
        }, showReactionsView: {message in
            reactionsForMessage = message
            showReactionsView.toggle()
        }, model: message.messageRow)
    }

    func createScrollToBottmView() -> some View {
        return VStack(alignment: .trailing, spacing: -10) {
            if model.numberOfNewMessages > 0 {
                Text("\(model.numberOfNewMessages)")
                    .font(.system(size: 12))
                    .padding(.trailing, 6.0)
                    .padding(.leading, 6.0)
                    .padding(.top, 1.0)
                    .padding(.bottom, 1.0)
                    .background(Color(model.swarmColor))
                    .cornerRadius(9)
                    .foregroundColor(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 9)
                            .stroke(Color.white, lineWidth: 1)
                    )
                    .zIndex(1)
            }
            Button(action: {
                model.scrollToTheBottom()
            }, label: {
                Image(systemName: "arrow.down")
                    .font(.system(size: 16))
                    .frame(width: 35, height: 35)
                    .overlay(
                        Circle()
                            .stroke(Color(model.swarmColor), lineWidth: 1)
                    )
                    .background( VisualEffect(style: .regular, withVibrancy: false))
                    .clipShape(Circle())
                    .foregroundColor(Color(model.swarmColor))
                    .frame(width: 45, height: 45)
                    .zIndex(0)
            })
        }
        .padding(.trailing, 5.0)
        .padding(.leading, 15.0)
        .padding(.top, 0.0)
        .padding(.bottom, 35)
        .ignoresSafeArea(.container, edges: [])
        .shadowForConversation()
    }

    func temporaryConversationView() -> some View {
        ZStack {
            Color(UIColor.systemBackground).edgesIgnoringSafeArea(.all)
            VStack {
                VStack {
                    Text(L10n.Conversation.notContactLabel(model.name))
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                    Text(L10n.Conversation.addToContactsLabel)
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                Spacer()
                Button(action: {
                    model.sendRequest()
                }, label: {
                    Text(L10n.Conversation.addToContactsButton)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .padding(.horizontal)
                })
                Spacer()
                    .frame(height: 20)
            }
        }
    }

    func syncView() -> some View {
        VStack {
            Text(model.syncMessage)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
    }

    func blockView() -> some View {
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
                        .foregroundColor(.jamiColor)
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

    private func hideKeyboardIfNeed() {
        if keyboardHeight > 0 {
            withAnimation {
                self.shouldHideActiveKeyboard = true
            }
            self.hideKeyboard()
            self.isMessageBarFocused = false
        }
    }

    private func handleKeyboardHeightChange(_ height: CGFloat) {
        /*
         If shouldHideActiveKeyboard is true, we don't track the
         keyboard height, as the keyboard is temporarily hidden
         and expected to reappear once the context menu is removed.
         */
        if !shouldHideActiveKeyboard {
            DispatchQueue.main.async {
                withAnimation {
                    keyboardHeight = height
                }
            }
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
            if shouldHideActiveKeyboard {
                isMessageBarFocused = true
                withAnimation {
                    shouldHideActiveKeyboard = false
                }
            }
        case .none, .shouldPresent, .dismissed:
            break
        case .willDismissWithTextEditingAction:
            if shouldHideActiveKeyboard {
                withAnimation {
                    shouldHideActiveKeyboard = false
                }
            }
        }
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
