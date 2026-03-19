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

/// Full-screen media preview.
/// Outer shell that owns the overlay state; the actual content lives in
/// `MediaPreviewContent` which directly observes the model.
struct MediaPreviewView: View {
    @ObservedObject var overlayState: MediaPreviewState

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

// MARK: - Content View (observes model directly)

/// Inner view that holds `@ObservedObject model` so SwiftUI
/// reacts to `model.activeSheet` changes for sheet presentation,
/// dim layer, and controls visibility.
private struct MediaPreviewContentView: View {
    @ObservedObject var model: MediaPreviewModel
    @ObservedObject var overlayState: MediaPreviewState
    let geometry: GeometryProxy

    private let doubleTapZoomScale: CGFloat = 3
    @SwiftUI.State private var imageScale: CGFloat = 1
    @SwiftUI.State private var lastScale: CGFloat = 1
    @SwiftUI.State private var imageOffset: CGSize = .zero
    @SwiftUI.State private var lastOffset: CGSize = .zero

    @SwiftUI.State private var controlsVisible: Bool = false
    @SwiftUI.State private var showDeleteConfirmation: Bool = false
    private let thumbnailCornerRadius: CGFloat = 15

    var body: some View {
        let screenRect = CGRect(origin: .zero, size: geometry.size)
        let usesFade = !overlayState.hasSourceFrame
        let targetRect = overlayState.isExpanded ? screenRect : (usesFade ? screenRect : overlayState.sourceFrame)
        let currentCornerRadius = (overlayState.isExpanded || usesFade) ? 0 : thumbnailCornerRadius
        let contentOpacity = usesFade ? (overlayState.isExpanded ? 1.0 : 0.0) : 1.0
        let backgroundAlpha: Double = overlayState.isExpanded ? 1.0 : 0.0
        let windowInsets = UIWindow.currentSafeAreaInsets
        let navBarBottom = overlayState.navBarBottomY

        ZStack {
            Color.black
                .opacity(backgroundAlpha)

            mediaContent()
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
                        }
                    )
                }

            if overlayState.isExpanded && !overlayState.isDismissing {
                overlayControls(safeArea: windowInsets)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .statusBarHidden(overlayState.isExpanded && !controlsVisible)
        .alert(isPresented: $showDeleteConfirmation) {
            Alert(
                title: Text(L10n.Global.deleteMessage),
                primaryButton: .destructive(Text(L10n.Actions.deleteAction)) {
                    model.delete()
                    dismiss()
                },
                secondaryButton: .cancel()
            )
        }
        .sheet(item: $model.activeSheet) { sheet in
            sheetContent(for: sheet)
        }
        .onChange(of: overlayState.isExpanded) { expanded in
            if expanded {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        controlsVisible = true
                    }
                }
            }
        }
        .onChange(of: controlsVisible) { _ in
            if controlsVisible {
                scheduleAutoHide()
            } else {
                overlayState.autoHideTaskHolder.task?.cancel()
            }
        }
        .onChange(of: model.activeSheet?.id) { sheetID in
            if sheetID != nil {
                overlayState.autoHideTaskHolder.task?.cancel()
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
        case .player(let viewModel):
            PlayerView(viewModel: viewModel, sizeMode: .fullScreen, withControls: true,
                       externalControlsVisible: $controlsVisible)
        case .image(let image):
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .scaleEffect(imageScale)
                .offset(imageOffset)
                .gesture(magnificationGesture)
                .gesture(imageDragGesture)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) { toggleZoom() }
                .onTapGesture(count: 1) { toggleControls() }
        }
    }

    // MARK: - Gestures

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                imageScale = max(1, lastScale * value)
            }
            .onEnded { value in
                lastScale = max(1, lastScale * value)
                imageScale = lastScale
                if imageScale <= 1 {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        imageOffset = .zero
                        lastOffset = .zero
                    }
                }
            }
    }

    private var imageDragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard imageScale > 1 else { return }
                imageOffset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                guard imageScale > 1 else { return }
                lastOffset = imageOffset
            }
    }

    // MARK: - Controls

    @ViewBuilder
    private func overlayControls(safeArea: UIEdgeInsets) -> some View {
        VStack {
            if controlsVisible {
                topBar(safeArea: safeArea)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            Spacer()
            if controlsVisible && model.isImagePreview {
                bottomBar(safeArea: safeArea)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .allowsHitTesting(controlsVisible)
    }

    private func topBar(safeArea: UIEdgeInsets) -> some View {
        HStack {
            glassLabelButton(text: L10n.Global.close, action: dismiss)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, safeArea.top)
    }

    private func bottomBar(safeArea: UIEdgeInsets) -> some View {
        HStack(spacing: 24) {
            glassIconButton(systemName: "square.and.arrow.up") { model.share() }
            glassIconButton(systemName: "arrowshape.turn.up.right") { model.forward() }
            glassIconButton(systemName: "square.and.arrow.down") { model.save() }
            if model.canDelete {
                glassIconButton(systemName: "trash") {
                    showDeleteConfirmation = true
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .glassCapsuleBackground()
        .padding(.bottom, safeArea.bottom)
    }

    // MARK: - Sheet Content

    @ViewBuilder
    private func sheetContent(for sheet: MediaPreviewSheet) -> some View {
        switch sheet {
        case .share(let url):
            ShareSheet(activityItems: [url])
        case .forward(let injectionBag, let callback):
            ForwardContactPicker(injectionBag: injectionBag, callback: callback)
        case .saveToFiles(let url):
            ExportDocumentPicker(url: url)
        }
    }

    // MARK: - Actions

    private func dismiss() {
        controlsVisible = false
        imageScale = 1
        lastScale = 1
        imageOffset = .zero
        lastOffset = .zero
        overlayState.dismiss()
    }

    private func toggleZoom() {
        withAnimation(.easeInOut(duration: 0.25)) {
            if imageScale > 1 {
                imageScale = 1
                lastScale = 1
                imageOffset = .zero
                lastOffset = .zero
            } else {
                imageScale = doubleTapZoomScale
                lastScale = doubleTapZoomScale
            }
        }
    }

    private func toggleControls() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            controlsVisible.toggle()
        }
    }

    private func scheduleAutoHide() {
        let holder = overlayState.autoHideTaskHolder
        holder.task?.cancel()
        holder.task = Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    controlsVisible = false
                }
            }
        }
    }
}

// MARK: - Forward Contact Picker (wraps existing ContactPickerView)

private struct ForwardContactPicker: View {
    @StateObject private var viewModel: ContactPickerViewModel
    @Environment(\.presentationMode) private var presentationMode
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

// MARK: - Export Document Picker

private struct ExportDocumentPicker: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        UIDocumentPickerViewController(forExporting: [url], asCopy: true)
    }

    func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) {}
}
