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
    private let thumbnailCornerRadius: CGFloat = 15

    var body: some View {
        GeometryReader { geometry in
            if let model = overlayState.model {
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

                    mediaContent(model: model)
                        .frame(width: targetRect.width, height: targetRect.height)
                        .clipShape(RoundedRectangle(cornerRadius: currentCornerRadius, style: .continuous))
                        .opacity(contentOpacity)
                        .position(
                            x: targetRect.midX,
                            y: targetRect.midY
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
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityAddTraits(.isModal)
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
                overlayState.autoHideTaskHolder.task?.cancel()
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
