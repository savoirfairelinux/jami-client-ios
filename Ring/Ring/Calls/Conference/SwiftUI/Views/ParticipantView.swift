/*
 *  Copyright (C) 2023 Savoir-faire Linux Inc.
 *
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
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

struct DisplayLayerView: UIViewRepresentable {

    @Binding var displayLayer: AVSampleBufferDisplayLayer
    @Binding var layerWidth: CGFloat
    @Binding var layerHeight: CGFloat

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.layer.addSublayer(displayLayer)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        var frame = displayLayer.frame
        let size = CGSize(width: layerWidth, height: layerHeight)
        if frame.size != size {
            frame.size = size
            displayLayer.frame = frame
        }
    }
}

struct ExpandableParticipantView: View {
    @ObservedObject var model: ParticipantViewModel
    @Binding var isAnimatingTopMainGrid: Bool
    @Binding var showMainGridView: Bool
    @SwiftUI.State var layerWidth: CGFloat = 0
    @SwiftUI.State var layerHeight: CGFloat = 0
    var viewWidth: CGFloat
    var viewHeight: CGFloat
    @SwiftUI.State var maxHeight: CGFloat = 0
    @SwiftUI.State var offsetX: CGFloat = 0
    var body: some View {
        if shouldShowOverlayColorView {
            overlayColorView
        } else {
            GeometryReader { geometry in
                selectedImageView
                    .onChange(of: [showMainGridView, model.notActiveParticipant]) { _ in
                        updateLayerDimensions()
                    }
                    .onAppear {
                        initializeLayerDimensions(geometry)
                    }
                    .onChange(of: geometry.size.height) { height in
                        let frame = geometry.frame(in: CoordinateSpace.global)
                        offsetX = frame.origin.x
                        maxHeight = height
                        updateLayerDimensions()
                    }
            }
            .frame(width: layerWidth)
        }
    }

    private var shouldShowOverlayColorView: Bool {
        return !showMainGridView && model.notActiveParticipant
    }

    private var overlayColorView: some View {
        Color(.clear)
            .frame(height: isAnimatingTopMainGrid ? 0 : viewHeight)
    }

    private var selectedImageView: some View {
        DisplayLayerView(displayLayer: $model.mainDisplayLayer, layerWidth: $layerWidth, layerHeight: $layerHeight)
            .offset(x: model.notActiveParticipant ? 0 : -offsetX)
            .frame(width: layerWidth, height: layerHeight)
            .onAppear {
                model.subscribe()
            }
            .onDisappear {
                model.unsubscribe()
            }
    }

    private func initializeLayerDimensions(_ geometry: GeometryProxy) {
        layerWidth = calculateNewWidth()
        layerHeight = calculateInitialHeight(geometry)
    }

    private func calculateInitialHeight(_ geometry: GeometryProxy) -> CGFloat {
        if showMainGridView || model.notActiveParticipant {
            return viewHeight
        } else {
            return geometry.size.height
        }
    }

    private func updateLayerDimensions() {
        let newWidth = calculateNewWidth()
        let newHeight = calculateNewHeight()
        if newHeight != layerHeight || newWidth != layerWidth {
            withAnimation {
                layerHeight = newHeight
                layerWidth = newWidth
            }
        }
    }

    private func calculateNewHeight() -> CGFloat {
        if showMainGridView || model.notActiveParticipant {
            return viewHeight
        } else {
            return maxHeight
        }
    }

    private func calculateNewWidth() -> CGFloat {
        if showMainGridView || model.notActiveParticipant {
            return viewWidth
        } else {
            return UIScreen.main.bounds.size.width
        }
    }
}

struct ParticipantView: View {
    @ObservedObject var model: ParticipantViewModel
    @SwiftUI.State var width: CGFloat
    @SwiftUI.State var height: CGFloat
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if model.notActiveParticipant {
                DisplayLayerView(displayLayer: $model.gridDisplayLayer, layerWidth: $width, layerHeight: $height)
                    .frame(width: width, height: height)
                    .cornerRadius(15)
                    .clipped()
                    .onAppear {
                        model.subscribe()
                    }
                    .onDisappear {
                        model.unsubscribe()
                    }

            }
        }
        .padding(2)
    }
}
