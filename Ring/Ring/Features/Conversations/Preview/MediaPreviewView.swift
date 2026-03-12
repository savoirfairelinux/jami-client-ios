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
    let model: MediaPreviewModel
    @Environment(\.presentationMode)
    private var presentationMode
    private let doubleTapZoomScale: CGFloat = 3
    @SwiftUI.State private var imageScale: CGFloat = 1
    @SwiftUI.State private var lastScale: CGFloat = 1
    @SwiftUI.State private var imageOffset: CGSize = .zero
    @SwiftUI.State private var lastOffset: CGSize = .zero
    @SwiftUI.State private var controlsVisible: Bool = true
    @SwiftUI.State private var hideTaskHolder = HideTaskHolder()

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                contentView
                overlayControls(safeArea: geometry.safeAreaInsets)
            }
            .ignoresSafeArea()
        }
        .statusBarHidden(!controlsVisible)
        .onAppear {
            scheduleAutoHide()
        }
        .onChange(of: controlsVisible) { _ in
            if controlsVisible {
                scheduleAutoHide()
            } else {
                hideTaskHolder.task?.cancel()
            }
        }
    }

    // MARK: - Content

    @ViewBuilder private var contentView: some View {
        switch model.content {
        case .player(let viewModel):
            PlayerView(viewModel: viewModel, sizeMode: .fullScreen, withControls: true,
                       externalControlsVisible: $controlsVisible)
        case .image(let image):
            zoomableImage(image)
        }
    }

    @ViewBuilder
    private func zoomableImage(_ image: UIImage) -> some View {
        GeometryReader { geo in
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .scaleEffect(imageScale)
                .offset(imageOffset)
                .frame(width: geo.size.width, height: geo.size.height)
                .gesture(magnificationGesture)
                .gesture(dragGesture)
                // Double-tap takes priority; single-tap is subordinate to avoid conflict
                .gesture(
                    TapGesture(count: 2)
                        .onEnded {
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
                        .exclusively(before: TapGesture(count: 1)
                                        .onEnded { toggleControls() }
                        )
                )
        }
    }

    // MARK: - Gestures

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let newScale = lastScale * value
                imageScale = max(1, newScale)
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

    private var dragGesture: some Gesture {
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

    // MARK: - Actions

    private func dismiss() {
        presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - HideTaskHolder

private final class HideTaskHolder {
    var task: Task<Void, Never>?
}

// MARK: - Overlay Controls

extension MediaPreviewView {
    @ViewBuilder private func overlayControls(safeArea: EdgeInsets) -> some View {
        VStack {
            if controlsVisible {
                topBar
                    .padding(.top, safeArea.top)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            Spacer()
            if controlsVisible && model.isImagePreview {
                bottomBar
                    .padding(.bottom, safeArea.bottom)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .allowsHitTesting(controlsVisible)
    }

    private var topBar: some View {
        HStack {
            glassLabelButton(text: L10n.Global.close, action: dismiss)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var bottomBar: some View {
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
        .padding(.bottom, 16)
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
