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

let width: CGFloat = 100
let height: CGFloat = 150
let marginVertical: CGFloat = 100
let marginHorizontal: CGFloat = 20

struct DragableCaptureView: View {
    private struct DraggablePositions {
        static var left = marginHorizontal + width * 0.5
        static var right = screenWidth - width * 0.5 - marginHorizontal
        static var bottom = screenHeight - height
        static let topRight = CGPoint(x: right, y: marginVertical)
        static let topLeft = CGPoint(x: left, y: marginVertical)
        static let bottomRight = CGPoint(x: right, y: bottom)
        static let bottomLeft = CGPoint(x: left, y: bottom)
        static let hiddenTopRight = CGPoint(x: screenWidth, y: marginVertical)
        static let hiddenTopLeft = CGPoint(x: 0, y: marginVertical)
        static let hiddenBottomRight = CGPoint(x: screenWidth, y: bottom)
        static let hiddenBottomLeft = CGPoint(x: 0, y: bottom)

        static func isHidden(_ position: CGPoint) -> Bool {
            let hiddenPositions: [CGPoint] = [hiddenTopLeft, hiddenTopRight, hiddenBottomLeft, hiddenBottomRight]
            return hiddenPositions.contains(position)
        }

        static func getToggledPosition(_ position: CGPoint) -> CGPoint {
            if position == DraggablePositions.topRight {
                return DraggablePositions.hiddenTopRight
            } else if position == DraggablePositions.topLeft {
                return DraggablePositions.hiddenTopLeft
            } else if position == DraggablePositions.bottomRight {
                return DraggablePositions.hiddenBottomRight
            } else if position == DraggablePositions.bottomLeft {
                return DraggablePositions.hiddenBottomLeft
            } else if position == DraggablePositions.hiddenTopRight {
                return DraggablePositions.topRight
            } else if position == DraggablePositions.hiddenTopLeft {
                return DraggablePositions.topLeft
            } else if position == DraggablePositions.hiddenBottomRight {
                return DraggablePositions.bottomRight
            } else if position == DraggablePositions.hiddenBottomLeft {
                return DraggablePositions.bottomLeft
            } else {
                return position
            }
        }
    }

    @SwiftUI.State private var location: CGPoint = DraggablePositions.topRight
    @GestureState private var currentLocation: CGPoint?
    @GestureState private var startLocation: CGPoint?
    @SwiftUI.State var alignment: Alignment = .leading
    @SwiftUI.State var showIndicator: Bool = false
    @Binding var image: UIImage
    @SwiftUI.State var hide: Bool = true
    let namespace: Namespace.ID
    let capturedVideoId = "capturedVideoId"

    var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                var newLocation = startLocation ?? location // 3
                newLocation.x += value.translation.width
                newLocation.y += value.translation.height

                let isOutsideVerticalBounds = isOutsideVerticalBounds(value.location)
                let isOutsideHorizontalBounds = isOutsideHorizontalBounds(value.location)

                let isTrailing = isTrailing(value.location)
                withAnimation {
                    hide = isOutsideVerticalBounds || isOutsideHorizontalBounds
                }
                alignment = isTrailing ? .leading : .trailing

                self.location = newLocation
                showIndicator = isOutsideHorizontalBounds
            }
            .updating($startLocation) { (_, startLocation, _) in
                startLocation = startLocation ?? location
            }
            .onEnded { value in
                let isTop = isTop(value.location)
                let isTrailing = isTrailing(value.location)
                var finalLocation: CGPoint

                switch (isTop, isTrailing) {
                case (false, false):
                    finalLocation = hide ? DraggablePositions.hiddenBottomLeft : DraggablePositions.bottomLeft
                case (false, true):
                    finalLocation = hide ? DraggablePositions.hiddenBottomRight : DraggablePositions.bottomRight
                case (true, false):
                    finalLocation = hide ? DraggablePositions.hiddenTopLeft : DraggablePositions.topLeft
                case (true, true):
                    finalLocation = hide ? DraggablePositions.hiddenTopRight : DraggablePositions.topRight
                }
                self.animatePositionChange(to: finalLocation)
            }
    }

    var currentDrag: some Gesture {
        DragGesture()
            .updating($currentLocation) { (value, fingerLocation, _) in
                fingerLocation = value.location
            }
    }

    func isOutsideVerticalBounds(_ point: CGPoint) -> Bool {
        return point.y > screenHeight || point.y < 0
    }

    func isOutsideHorizontalBounds(_ point: CGPoint) -> Bool {
        return point.x > screenWidth - (marginHorizontal * 1.5) || point.x < marginHorizontal * 1.5
    }

    func isTop(_ point: CGPoint) -> Bool {
        return point.y <= screenHeight / 2
    }

    func isTrailing(_ point: CGPoint) -> Bool {
        return point.x > screenWidth / 2
    }

    var body: some View {
        ZStack {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .cornerRadius(15)
            ZStack(alignment: alignment) {
                VisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterialDark))
                    .opacity( hide ? 1 : 0)
                    .transition(.opacity)
                    .cornerRadius(15)
                if showIndicator {
                    Indicator(orientation: .vertical).padding()
                }
            }
        }
        .id(capturedVideoId)
        .matchedGeometryEffect(id: capturedVideoId, in: namespace)
        .transition(.scale(scale: 1))
        .frame(width: width, height: height)
        .position(location)
        .gesture(
            dragGesture.simultaneously(with: currentDrag)
        )
        .onAppear {
            withAnimation(.dragableCaptureViewAnimation()) {
                hide = false
            }
        }
        .onTapGesture {
            withAnimation {
                hide.toggle()
            }
            let postion = DraggablePositions.getToggledPosition(location)
            self.animatePositionChange(to: postion)
        }
    }

    func animatePositionChange(to newPosition: CGPoint) {
        withAnimation(.dragableCaptureViewAnimation()) {
            self.location = newPosition
            let showIndicator = DraggablePositions.isHidden(self.location)
            DispatchQueue.main.asyncAfter(deadline: .now() + (showIndicator ? 0.5 : 0)) {
                self.showIndicator = showIndicator
            }
        }
    }
}
