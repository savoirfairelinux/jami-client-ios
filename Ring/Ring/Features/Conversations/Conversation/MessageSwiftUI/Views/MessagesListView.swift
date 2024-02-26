/*
 *  Copyright (C) 2022 Savoir-faire Linux Inc.
 *
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
 *  Author: Alireza Toghiani Khorasgani alireza.toghiani@savoirfairelinux.com
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
import RxSwift
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

struct MessagesListView: View {
    @StateObject var model: MessagesListVM
    var screenTapped: Observable<Bool>
    @SwiftUI.State var showScrollToLatestButton = false
    let scrollReserved = UIScreen.main.bounds.height * 1.5

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

    // reactions
    @SwiftUI.State private var reactionsForMessage: ReactionsContainerModel?
    @SwiftUI.State private var showReactionsView = false

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
                    MessagePanelView(model: model.messagePanel, isFocused: $isMessageBarFocused)
                        .alignmentGuide(VerticalAlignment.center) { dimensions in
                            DispatchQueue.main.async {
                                self.messageContainerHeight = dimensions.height
                            }
                            return dimensions[VerticalAlignment.center]
                        }
                }
                .overlay(contextMenuPresentingState == .shouldPresent && model.contextMenuModel.presentingMessage != nil ? makeOverlay() : nil)
                // hide navigation bar when presenting context menu
                .onChange(of: contextMenuPresentingState) { newValue in
                    let shouldHide = newValue == .shouldPresent
                    model.hideNavigationBar.accept(shouldHide)
                }
                // hide context menu overly when device is rotated
                .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        if screenHeight != UIScreen.main.bounds.size.height && screenHeight != 0 {
                            screenHeight = UIScreen.main.bounds.size.height
                            contextMenuPresentingState = .dismissed
                            self.shouldHideActiveKeyboard = false
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .emojiReactionEvent)) { notification in
                    if let event = notification.object as? EmojiReactionEvent {
                        contextMenuPresentingState = .dismissed
                    }
                }
                .onAppear(perform: {
                    screenHeight = UIScreen.main.bounds.size.height
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
        }
        .onAppear {
            /* We cannot use SwiftUI's onTapGesture here because it would
             interfere with the interactions of the buttons in the player view.
             Instead, we are using UITapGestureRecognizer from UIView.
             */
            setupTapAction()
        }
    }

    private func setupTapAction() {
        screenTapped
            .subscribe(onNext: { _ in
                self.showReactionsView = false
                reactionsForMessage = nil
                hideKeyboard()
            })
            .disposed(by: model.disposeBag)
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
                    // messages
                    ForEach(model.messagesModels) { message in
                        createMessageRowView(for: message)
                            .id(message.id)
                    }
                    .flipped()
                    // load more
                    Text("")
                        .onAppear(perform: {
                            DispatchQueue.global(qos: .background)
                                .asyncAfter(deadline: DispatchTime(uptimeNanoseconds: 10)) {
                                    self.model.loadMore()
                                }
                        })
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
// stuff for hiding ContextMenuView after using MCEmojiPicker
struct EmojiReactionEvent {}

extension Notification.Name {
    static let emojiReactionEvent = Notification.Name("EmojiReactionEvent")
}

class EmojiReactionNotifier {
    static let shared = EmojiReactionNotifier()
    
    private init() {}
    
    func notifyEmojiReaction(event: EmojiReactionEvent) {
        NotificationCenter.default.post(name: .emojiReactionEvent, object: event)
    }
}
