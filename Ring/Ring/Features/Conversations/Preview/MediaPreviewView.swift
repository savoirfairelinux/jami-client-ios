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
/// Animates a floating image from the thumbnail's captured frame to full screen
struct MediaPreviewView: View {
    @ObservedObject var overlayState: MediaPreviewState

    private let doubleTapZoomScale: CGFloat = 3
    @SwiftUI.State private var imageScale: CGFloat = 1
    @SwiftUI.State private var lastScale: CGFloat = 1
    @SwiftUI.State private var imageOffset: CGSize = .zero
    @SwiftUI.State private var lastOffset: CGSize = .zero

    @SwiftUI.State private var controlsVisible: Bool = false
    @SwiftUI.State private var hideTaskHolder = PreviewAutoHideTaskHolder()
    @SwiftUI.State private var dragOffset: CGFloat = 0
    @SwiftUI.State private var isDraggingToDismiss: Bool = false
    private let thumbnailCornerRadius: CGFloat = 15

    var body: some View {
        GeometryReader { geometry in
            if let model = overlayState.model {
                let screenRect = CGRect(origin: .zero, size: geometry.size)
                let usesFade = !overlayState.hasSourceFrame
                let targetRect = overlayState.isExpanded ? screenRect : (usesFade ? screenRect : overlayState.sourceFrame)
                let currentCornerRadius = (overlayState.isExpanded || usesFade) ? 0 : thumbnailCornerRadius
                let contentOpacity = usesFade ? (overlayState.isExpanded ? 1.0 : 0.0) : 1.0
                let backgroundAlpha = overlayState.isExpanded ? (1.0 - min(abs(dragOffset) / 200.0, 0.5)) : 0.0
                let windowInsets = UIWindow.currentSafeAreaInsets

                // The nav bar height from the presenting view controller.
                // Used to clip media content during collapse so it doesn't
                // appear above the navigation bar.
                let navBarBottom = Self.navBarBottomY

                ZStack {
                    Color.black
                        .opacity(backgroundAlpha)

                    mediaContent(model: model)
                        .frame(width: targetRect.width, height: targetRect.height)
                        .clipShape(RoundedRectangle(cornerRadius: currentCornerRadius, style: .continuous))
                        .opacity(contentOpacity)
                        .position(
                            x: targetRect.midX,
                            y: targetRect.midY + (overlayState.isExpanded ? dragOffset : 0)
                        )
                        // Clip to below the nav bar during collapse so the
                        // shrinking image doesn't render above it.
                        .if(!usesFade) { view in
                            view.mask(
                                VStack(spacing: 0) {
                                    Color.clear.frame(height: overlayState.isExpanded ? 0 : navBarBottom)
                                    Color.black
                                }
                            )
                        }

                    if overlayState.isExpanded && !overlayState.isDismissing {
                        overlayControls(model: model, safeArea: windowInsets)
                            .opacity(isDraggingToDismiss ? 0 : 1)
                    }
                }
            }
        }
        .ignoresSafeArea()
        .statusBarHidden(overlayState.isExpanded && !controlsVisible)
        .onChange(of: overlayState.isExpanded) { expanded in
            if expanded {
                // Show controls after expand animation completes
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
                hideTaskHolder.task?.cancel()
            }
        }
    }

    // MARK: - Media Content

    @ViewBuilder
    private func mediaContent(model: MediaPreviewModel) -> some View {
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
    private func overlayControls(model: MediaPreviewModel, safeArea: UIEdgeInsets) -> some View {
        VStack {
            if controlsVisible {
                topBar(safeArea: safeArea)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            Spacer()
            if controlsVisible && model.isImagePreview {
                bottomBar(model: model, safeArea: safeArea)
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

    private func bottomBar(model: MediaPreviewModel, safeArea: UIEdgeInsets) -> some View {
        HStack(spacing: 24) {
            glassIconButton(systemName: "square.and.arrow.up") { model.share() }
            glassIconButton(systemName: "arrowshape.turn.up.right") { model.forward() }
            glassIconButton(systemName: "square.and.arrow.down") { model.save() }
            glassIconButton(systemName: "trash") {
                model.delete()
                dismiss()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .glassCapsuleBackground()
        .padding(.bottom, safeArea.bottom)
    }

    // MARK: - Nav Bar Height

    /// Bottom Y of the navigation bar in global coordinates.
    /// Searches all windows at the normal level to find the navigation bar,
    /// since the overlay lives in its own window above the main one.
    private static var navBarBottomY: CGFloat {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first else { return 0 }
        // Look through normal-level windows for a navigation controller.
        for window in scene.windows where window.windowLevel == .normal {
            guard let rootVC = window.rootViewController else { continue }
            var candidate: UINavigationController?
            var current: UIViewController = rootVC
            if let nav = current as? UINavigationController {
                candidate = nav
            }
            while let presented = current.presentedViewController {
                if let nav = presented as? UINavigationController {
                    candidate = nav
                } else if let nav = presented.navigationController {
                    candidate = nav
                }
                current = presented
            }
            if let nav = candidate {
                let bar = nav.navigationBar
                let barFrame = bar.convert(bar.bounds, to: window)
                return barFrame.maxY
            }
        }
        return UIWindow.currentSafeAreaInsets.top
    }

    // MARK: - Actions

    private func dismiss() {
        controlsVisible = false
        imageScale = 1
        lastScale = 1
        imageOffset = .zero
        lastOffset = .zero
        dragOffset = 0
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
        hideTaskHolder.task?.cancel()
        hideTaskHolder.task = Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            await MainActor.run {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    controlsVisible = false
                }
            }
        }
    }
}
