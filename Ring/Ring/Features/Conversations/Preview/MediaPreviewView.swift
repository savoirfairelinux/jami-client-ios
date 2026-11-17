/*
 *  Copyright (C) 2020-2026 Savoir-faire Linux Inc.
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

struct MediaPreviewView: View {
    @ObservedObject var overlayState: MediaPreviewPresenter

    var body: some View {
        GeometryReader { geometry in
            if let model = overlayState.model {
                switch model.content {
                case .image(let image):
                    ImagePreviewScreen(image: image, model: model, overlayState: overlayState, size: geometry.size)
                case .player(let player):
                    VideoPreviewScreen(player: player, model: model, overlayState: overlayState, size: geometry.size)
                }
            }
        }
        .ignoresSafeArea()
    }
}

struct MediaPreviewShell<Media: View, Controls: View>: View {
    @ObservedObject var model: MediaPreviewModel
    @ObservedObject var overlayState: MediaPreviewPresenter
    let size: CGSize
    @Binding var chromeVisible: Bool
    let allowsDismissDrag: Bool
    let menuActions: [MediaPreviewMenuAction]
    @ViewBuilder let media: (_ onTap: @escaping () -> Void) -> Media
    @ViewBuilder let controls: () -> Controls

    @SwiftUI.State private var bottomChromeHeight: CGFloat = 0

    private let thumbnailCornerRadius: CGFloat = 15
    private let dismissThreshold: CGFloat = 120

    private var safeArea: UIEdgeInsets { UIWindow.currentSafeAreaInsets }

    private var isSettled: Bool {
        overlayState.isExpanded && !overlayState.isDismissing
    }

    private var showsHeader: Bool { isSettled && chromeVisible }
    private var showsBottomChrome: Bool { isSettled && chromeVisible }

    var body: some View {
        let usesFade = !overlayState.hasSourceFrame
        let screenRect = CGRect(origin: .zero, size: size)
        let targetRect = overlayState.isExpanded ? screenRect : (usesFade ? screenRect : overlayState.sourceFrame)
        let cornerRadius: CGFloat = (overlayState.isExpanded || usesFade) ? 0 : thumbnailCornerRadius
        let contentOpacity = usesFade ? (overlayState.isExpanded ? 1.0 : 0.0) : 1.0
        let bottomClip = max(0, size.height - overlayState.messagePanelTopY)

        ZStack {
            Color.black.opacity(overlayState.backgroundAlpha)
                .contentShape(Rectangle())
                .onTapGesture(perform: handleTap)
                .gesture(allowsDismissDrag ? dismissDrag : nil)

            media(handleTap)
                .frame(width: targetRect.width, height: targetRect.height)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .opacity(contentOpacity)
                .position(x: targetRect.midX, y: targetRect.midY)
                .gesture(allowsDismissDrag ? dismissDrag : nil)
                .if(!usesFade) { view in
                    view.mask(
                        VStack(spacing: 0) {
                            Color.clear.frame(height: overlayState.isExpanded ? 0 : overlayState.navBarBottomY)
                            Color.black
                            Color.clear.frame(height: overlayState.isExpanded ? 0 : bottomClip)
                        }
                    )
                }

            chrome
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .animation(MediaPreviewLayout.chromeAnimation, value: showsHeader)
        .animation(MediaPreviewLayout.chromeAnimation, value: showsBottomChrome)
        .animation(.spring(response: 0.3, dampingFraction: 0.82), value: model.isReacting)
        .overlay(savedToast)
        .onChange(of: model.saveSuccess, perform: savedStateChanged)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: model.saveSuccess)
        .alert(isPresented: Binding<Bool>(
            get: { model.saveError != nil },
            set: { if !$0 { model.saveError = nil } }
        )) {
            Alert(
                title: Text(L10n.Conversation.errorSavingImage),
                message: Text(L10n.Conversation.errorSavingImageMessage),
                dismissButton: .default(Text(L10n.Global.ok))
            )
        }
        .alert(isPresented: $model.needsPhotoPermission) {
            Alert(
                title: Text(L10n.Alerts.noLibraryPermissionsTitle),
                message: Text(L10n.Conversation.photoAccessRequiredMessage),
                primaryButton: .default(Text(L10n.Actions.goToSettings)) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                },
                secondaryButton: .cancel(Text(L10n.Global.cancel))
            )
        }
        .sheet(item: $model.activeSheet) { sheet in
            MediaPreviewSheetContent(sheet: sheet)
        }
        .onChange(of: overlayState.isExpanded) { expanded in
            guard expanded else { return }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 450_000_000)
                guard overlayState.isExpanded && !overlayState.isDismissing else { return }
                chromeVisible = true
            }
        }
        .onChange(of: model.activeSheet?.id) { sheetID in
            if sheetID != nil {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    chromeVisible = false
                }
            } else {
                chromeVisible = true
            }
        }
    }

    // MARK: - Chrome

    @ViewBuilder private var chrome: some View {
        ZStack {
            VStack(spacing: 0) {
                if showsHeader {
                    MediaPreviewScrim(edge: .top, chromeHeight: safeArea.top + MediaPreviewLayout.control)
                        .transition(.opacity)
                }
                Spacer(minLength: 0)
                if showsBottomChrome {
                    MediaPreviewScrim(edge: .bottom, chromeHeight: bottomChromeHeight)
                        .transition(.opacity)
                }
            }
            VStack(spacing: 0) {
                if showsHeader {
                    MediaPreviewHeader(title: model.title,
                                       subtitle: model.subtitle,
                                       menuActions: menuActions,
                                       onClose: close)
                        .padding(.top, safeArea.top)
                        .transition(.opacity)
                }
                Spacer(minLength: 0)
                if showsBottomChrome {
                    bottomChrome
                        .transition(.opacity)
                }
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private var bottomChrome: some View {
        VStack(spacing: MediaPreviewLayout.bottomStackSpacing) {
            controls()
            reactionsArea
            MediaPreviewActionCapsule(model: model)
        }
        .padding(.horizontal, MediaPreviewLayout.sideInset)
        .padding(.bottom, max(safeArea.bottom + MediaPreviewLayout.capsuleBottomOffset, 12))
        .background(GeometryReader { proxy in
            Color.clear.preference(key: MediaPreviewBottomChromeHeightKey.self,
                                   value: size.height - proxy.frame(in: .global).minY)
        })
        .onPreferenceChange(MediaPreviewBottomChromeHeightKey.self) { bottomChromeHeight = $0 }
    }

    @ViewBuilder private var reactionsArea: some View {
        if model.isReacting {
            MediaPreviewReactionPicker(emojis: model.reactionChoices,
                                       activeEmojis: model.ownReactions,
                                       maxWidth: size.width - 2 * MediaPreviewLayout.sideInset,
                                       onPick: model.react)
                .transition(.scale(scale: 0.9).combined(with: .opacity))
        } else if let reactions = model.reactions {
            MediaPreviewReactionsSummary(reactions: reactions)
                .transition(.opacity)
        }
    }

    // MARK: - Interaction

    private var dismissDrag: some Gesture {
        DragGesture()
            .onEnded { value in
                let translation = value.translation.height
                let predicted = value.predictedEndTranslation.height
                if abs(translation) > dismissThreshold || abs(predicted) > 800 {
                    close()
                }
            }
    }

    func handleTap() {
        if model.isReacting {
            model.isReacting = false
            return
        }
        chromeVisible.toggle()
    }

    private func close() {
        chromeVisible = false
        overlayState.dismiss()
    }

    // MARK: - Saved toast

    @ViewBuilder private var savedToast: some View {
        if model.saveSuccess {
            SavedToast()
                .transition(.scale.combined(with: .opacity))
        }
    }

    private func savedStateChanged(_ success: Bool) {
        guard success else { return }
        UIAccessibility.post(notification: .announcement, argument: L10n.Conversation.imageSaved)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            model.saveSuccess = false
        }
    }
}

// MARK: - Menu actions

extension MediaPreviewModel {
    func menuActions(onDelete: @escaping () -> Void) -> [MediaPreviewMenuAction] {
        var actions = [MediaPreviewMenuAction]()
        if canSave {
            actions.append(MediaPreviewMenuAction(title: L10n.Global.save, systemName: "square.and.arrow.down", handler: save))
        }
        if isImagePreview {
            actions.append(MediaPreviewMenuAction(title: L10n.Global.copy, systemName: "doc.on.doc", handler: copy))
        }
        if canDelete {
            actions.append(MediaPreviewMenuAction(title: L10n.Actions.deleteAction, systemName: "trash", isDestructive: true, handler: onDelete))
        }
        return actions
    }
}

enum MediaPreviewDeleteConfirmation {
    static func present(onConfirm: @escaping () -> Void) {
        guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene }).first else { return }
        let overlayWindow = scene.windows
            .filter { !$0.isHidden }
            .sorted { $0.windowLevel.rawValue > $1.windowLevel.rawValue }
            .first
        guard var topVC = overlayWindow?.rootViewController else { return }
        while let presented = topVC.presentedViewController {
            topVC = presented
        }
        let alert = UIAlertController(title: L10n.Global.deleteMessage, message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L10n.Actions.deleteAction, style: .destructive) { _ in onConfirm() })
        alert.addAction(UIAlertAction(title: L10n.Global.cancel, style: .cancel))
        topVC.present(alert, animated: true)
    }
}

extension MediaPreviewPresenter {
    func deleteAndDismiss(_ model: MediaPreviewModel) {
        MediaPreviewDeleteConfirmation.present { [weak self] in
            model.delete()
            self?.hasSourceFrame = false
            self?.dismiss()
        }
    }
}

// MARK: - Layout keys

private struct MediaPreviewBottomChromeHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - Saved Toast

private struct SavedToast: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark")
                .font(.subheadline.weight(.semibold))
            Text(L10n.Conversation.imageSaved)
                .font(.subheadline.weight(.medium))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .frame(height: 40)
        .mediaPreviewGlass(in: Capsule())
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Sheet Content

private struct MediaPreviewSheetContent: View {
    let sheet: MediaPreviewSheet

    var body: some View {
        switch sheet {
        case .share(let url):
            ShareSheet(activityItems: [url])
        case .forward(let injectionBag, let callback):
            ForwardContactPicker(injectionBag: injectionBag, callback: callback)
        }
    }
}

// MARK: - Forward Contact Picker (wraps existing ContactPickerView)

private struct ForwardContactPicker: View {
    @StateObject private var viewModel: ContactPickerViewModel
    @Environment(\.presentationMode)
    private var presentationMode
    private let callback: ([String]) -> Void

    init(injectionBag: InjectionBag, callback: @escaping ([String]) -> Void) {
        self.callback = callback
        _viewModel = StateObject(wrappedValue: ContactPickerViewModel(with: injectionBag))
    }

    var body: some View {
        ContactPickerView(
            viewModel: viewModel,
            onDismissed: nil
        )
        .onAppear {
            viewModel.type = .forConversation
            viewModel.conversationSelectedCB = { selected in
                callback(selected)
            }
            viewModel.bind()
        }
    }
}
