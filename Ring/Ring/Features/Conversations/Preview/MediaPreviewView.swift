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
                MediaPreviewContentView(
                    model: model,
                    overlayState: overlayState,
                    geometry: geometry
                )
            }
        }
        .ignoresSafeArea()
    }
}

private struct MediaPreviewContentView: View {
    @ObservedObject var model: MediaPreviewModel
    @ObservedObject var overlayState: MediaPreviewPresenter
    let geometry: GeometryProxy

    @SwiftUI.State private var isImageZoomed: Bool = false

    @SwiftUI.State private var controlsVisible: Bool = false
    private let thumbnailCornerRadius: CGFloat = 15

    /// Distance the user must drag vertically before the preview dismisses.
    private let dismissThreshold: CGFloat = 120

    var body: some View {
        let screenRect = CGRect(origin: .zero, size: geometry.size)
        let usesFade = !overlayState.hasSourceFrame
        let targetRect = overlayState.isExpanded ? screenRect : (usesFade ? screenRect : overlayState.sourceFrame)
        let currentCornerRadius = (overlayState.isExpanded || usesFade) ? 0 : thumbnailCornerRadius
        let contentOpacity = usesFade ? (overlayState.isExpanded ? 1.0 : 0.0) : 1.0
        let windowInsets = UIWindow.currentSafeAreaInsets
        let navBarBottom = overlayState.navBarBottomY
        let bottomClip = max(0, geometry.size.height - overlayState.messagePanelTopY)

        ZStack {
            Color.black.opacity(overlayState.backgroundAlpha)
                .contentShape(Rectangle())
                .onTapGesture { toggleControls() }
                .gesture(dismissDragGesture)

            mediaContent()
                .offset(y: overlayState.dragOffset)
                .frame(width: targetRect.width, height: targetRect.height)
                .clipShape(RoundedRectangle(cornerRadius: currentCornerRadius, style: .continuous))
                .opacity(contentOpacity)
                .position(
                    x: targetRect.midX,
                    y: targetRect.midY
                )
                .if(!usesFade) { view in
                    view.mask(
                        VStack(spacing: 0) {
                            Color.clear.frame(height: overlayState.isExpanded ? 0 : navBarBottom)
                            Color.black
                            Color.clear.frame(height: overlayState.isExpanded ? 0 : bottomClip)
                        }
                    )
                }

            if overlayState.isExpanded && !overlayState.isDismissing && !overlayState.isDragging {
                MediaPreviewOverlayControls(
                    model: model,
                    controlsVisible: controlsVisible,
                    safeArea: windowInsets,
                    onDismiss: dismiss,
                    onDelete: { [self] in
                        presentDeleteAlert()
                    }
                )
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .overlay(
            Group {
                if model.saveSuccess {
                    SavedToast()
                        .transition(.scale.combined(with: .opacity))
                }
            }
        )
        .onChange(of: model.saveSuccess) { success in
            guard success else { return }
            UIAccessibility.post(notification: .announcement, argument: L10n.Conversation.imageSaved)
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    model.saveSuccess = false
                }
            }
        }
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
            if expanded {
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 450_000_000)
                    guard overlayState.isExpanded && !overlayState.isDismissing else { return }
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        controlsVisible = true
                    }
                }
            }
        }
        .onChange(of: controlsVisible) { _ in
            if controlsVisible {
                overlayState.scheduleAutoHide { [self] in
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        controlsVisible = false
                    }
                }
            } else {
                overlayState.cancelAutoHide()
            }
        }
        .onChange(of: model.activeSheet?.id) { sheetID in
            if sheetID != nil {
                overlayState.cancelAutoHide()
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    controlsVisible = false
                }
            } else {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    controlsVisible = true
                }
            }
        }
    }

    // MARK: - Media Content

    @ViewBuilder
    private func mediaContent() -> some View {
        switch model.content {
        case .video(let media, let poster):
            PlayerView(media: media, poster: poster, sizeMode: .fullScreen, withControls: true,
                       externalControlsVisible: $controlsVisible,
                       fullScreenActions: AnyView(MediaPreviewVideoActions(model: model, onDelete: { [self] in
                           presentDeleteAlert()
                       })))
                .gesture(
                    DragGesture()
                        .onEnded { value in
                            let translation = value.translation.height
                            let velocity = value.predictedEndTranslation.height
                            let shouldDismiss = abs(translation) > dismissThreshold
                                || abs(velocity) > 800
                            if shouldDismiss {
                                dismiss()
                            }
                        }
                )
        case .image(let image):
            ZoomableImageView(
                image: image,
                isZoomed: $isImageZoomed,
                onSingleTap: { toggleControls() },
                onPanBegan: { controlsVisible = false }
            )
                .gesture(isImageZoomed ? nil : dismissDragGesture)
                .accessibilityElement()
                .accessibilityAddTraits([.isButton, .isImage])
                .accessibilityAction(named: L10n.Global.close) { dismiss() }
        }
    }

    // MARK: - Gestures

    private var dismissDragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if controlsVisible && abs(value.translation.height) > 10 {
                    controlsVisible = false
                }
            }
            .onEnded { value in
                let translation = value.translation.height
                let velocity = value.predictedEndTranslation.height
                let shouldDismiss = abs(translation) > dismissThreshold
                    || abs(velocity) > 800
                if shouldDismiss {
                    dismiss()
                }
            }
    }

    // MARK: - Actions

    private func presentDeleteAlert() {
        guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene }).first else { return }
        let overlayWindow = scene.windows
            .filter { !$0.isHidden }
            .sorted { $0.windowLevel.rawValue > $1.windowLevel.rawValue }
            .first
        guard let presenter = overlayWindow?.rootViewController else { return }
        // Walk to the topmost presented controller.
        var topVC = presenter
        while let presented = topVC.presentedViewController {
            topVC = presented
        }
        let alert = UIAlertController(
            title: L10n.Global.deleteMessage,
            message: nil,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: L10n.Actions.deleteAction, style: .destructive) { [self] _ in
            model.delete()
            overlayState.hasSourceFrame = false
            dismiss()
        })
        alert.addAction(UIAlertAction(title: L10n.Global.cancel, style: .cancel))
        topVC.present(alert, animated: true)
    }

    private func dismiss() {
        controlsVisible = false
        isImageZoomed = false
        overlayState.dismiss()
    }

    private func toggleControls() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            controlsVisible.toggle()
        }
    }
}

// MARK: - Zoomable Image

private struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage
    @Binding var isZoomed: Bool
    let onSingleTap: () -> Void
    let onPanBegan: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> ZoomableImageScrollView {
        let scrollView = ZoomableImageScrollView()
        scrollView.delegate = context.coordinator
        let doubleTap = UITapGestureRecognizer(target: context.coordinator,
                                               action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        let singleTap = UITapGestureRecognizer(target: context.coordinator,
                                               action: #selector(Coordinator.handleSingleTap))
        singleTap.require(toFail: doubleTap)
        scrollView.addGestureRecognizer(doubleTap)
        scrollView.addGestureRecognizer(singleTap)
        return scrollView
    }

    func updateUIView(_ scrollView: ZoomableImageScrollView, context: Context) {
        context.coordinator.parent = self
        scrollView.setImage(image)
        if !isZoomed && scrollView.zoomScale > scrollView.minimumZoomScale {
            scrollView.setZoomScale(scrollView.minimumZoomScale, animated: false)
        }
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        var parent: ZoomableImageView
        private let doubleTapZoomScale: CGFloat = 3

        init(_ parent: ZoomableImageView) {
            self.parent = parent
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            (scrollView as? ZoomableImageScrollView)?.imageView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            (scrollView as? ZoomableImageScrollView)?.centerImage()
            let zoomed = scrollView.zoomScale > scrollView.minimumZoomScale
            scrollView.isScrollEnabled = zoomed
            if parent.isZoomed != zoomed {
                parent.isZoomed = zoomed
            }
        }

        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            parent.onPanBegan()
        }

        @objc
        func handleSingleTap() {
            parent.onSingleTap()
        }

        @objc
        func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
            guard let scrollView = recognizer.view as? ZoomableImageScrollView else { return }
            if scrollView.zoomScale > scrollView.minimumZoomScale {
                scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
                return
            }
            let point = recognizer.location(in: scrollView.imageView)
            let size = CGSize(width: scrollView.bounds.width / doubleTapZoomScale,
                              height: scrollView.bounds.height / doubleTapZoomScale)
            let rect = CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2,
                              width: size.width, height: size.height)
            scrollView.zoom(to: rect, animated: true)
        }
    }
}

private final class ZoomableImageScrollView: UIScrollView {
    let imageView = UIImageView()
    private var fittedBoundsSize: CGSize = .zero

    init() {
        super.init(frame: .zero)
        imageView.contentMode = .scaleAspectFit
        addSubview(imageView)
        minimumZoomScale = 1
        maximumZoomScale = 5
        bouncesZoom = true
        isScrollEnabled = false
        showsVerticalScrollIndicator = false
        showsHorizontalScrollIndicator = false
        contentInsetAdjustmentBehavior = .never
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setImage(_ image: UIImage) {
        guard imageView.image !== image else { return }
        imageView.image = image
        fittedBoundsSize = .zero
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if bounds.size != fittedBoundsSize && zoomScale == minimumZoomScale {
            fitImage()
        }
        centerImage()
    }

    private func fitImage() {
        fittedBoundsSize = bounds.size
        guard let imageSize = imageView.image?.size,
              imageSize.width > 0, imageSize.height > 0,
              bounds.width > 0, bounds.height > 0 else { return }
        let scale = min(bounds.width / imageSize.width, bounds.height / imageSize.height)
        let fittedSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        imageView.frame = CGRect(origin: .zero, size: fittedSize)
        contentSize = fittedSize
    }

    func centerImage() {
        let horizontalInset = max(0, (bounds.width - contentSize.width) / 2)
        let verticalInset = max(0, (bounds.height - contentSize.height) / 2)
        let inset = UIEdgeInsets(top: verticalInset, left: horizontalInset,
                                 bottom: verticalInset, right: horizontalInset)
        if contentInset != inset {
            contentInset = inset
        }
    }
}

// MARK: - Overlay Controls

private struct MediaPreviewOverlayControls: View {
    let model: MediaPreviewModel
    let controlsVisible: Bool
    let safeArea: UIEdgeInsets
    let onDismiss: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack {
            if controlsVisible {
                MediaPreviewTopBar(safeArea: safeArea, onDismiss: onDismiss)
                    .transition(.opacity)
            }
            Spacer()
            if controlsVisible && model.isImagePreview {
                MediaPreviewBottomBar(model: model, safeArea: safeArea, onDelete: onDelete)
                    .transition(.opacity)
            }
        }
        .allowsHitTesting(controlsVisible)
    }
}

private struct MediaPreviewTopBar: View {
    let safeArea: UIEdgeInsets
    let onDismiss: () -> Void

    var body: some View {
        HStack {
            glassLabelButton(text: L10n.Global.close, action: onDismiss)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, safeArea.top)
    }
}

private struct MediaPreviewVideoActions: View {
    let model: MediaPreviewModel
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            actionButton(systemName: "square.and.arrow.up", accessibilityLabel: L10n.Global.share, action: model.share)
            actionButton(systemName: "arrowshape.turn.up.right", accessibilityLabel: L10n.Global.forward, action: model.forward)
            if model.canDelete {
                actionButton(systemName: "trash", accessibilityLabel: L10n.Actions.deleteAction, action: onDelete)
            }
        }
        .padding(.horizontal, 6)
        .glassCapsuleBackground()
    }

    private func actionButton(systemName: String, accessibilityLabel: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct MediaPreviewBottomBar: View {
    let model: MediaPreviewModel
    let safeArea: UIEdgeInsets
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 24) {
            glassIconButton(systemName: "square.and.arrow.up", accessibilityLabel: L10n.Global.share) { model.share() }
            glassIconButton(systemName: "arrowshape.turn.up.right", accessibilityLabel: L10n.Global.forward) { model.forward() }
            glassIconButton(systemName: "square.and.arrow.down", accessibilityLabel: L10n.Global.save) { model.save() }
            if model.canDelete {
                glassIconButton(systemName: "trash", accessibilityLabel: L10n.Actions.deleteAction) {
                    onDelete()
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .glassCapsuleBackground()
        .padding(.bottom, safeArea.bottom)
    }
}

// MARK: - Saved Toast

private struct SavedToast: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .semibold))
            Text(L10n.Conversation.imageSaved)
                .font(.system(size: 15, weight: .medium))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .frame(height: 40)
        .glassCapsuleBackground()
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
