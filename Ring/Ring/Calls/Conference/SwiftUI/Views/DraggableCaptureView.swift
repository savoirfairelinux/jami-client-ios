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
let height: CGFloat = 130

var marginVertical: CGFloat = 100
var marginHorizontal: CGFloat {
    return UIDevice.current.orientation.isLandscape ? 50 : 20
}

struct DraggablePositions {
    var left: CGFloat
    var right: CGFloat
    var bottom: CGFloat
    var topRight: CGPoint
    var topLeft: CGPoint
    var bottomRight: CGPoint
    var bottomLeft: CGPoint
    var hiddenTopRight: CGPoint
    var hiddenTopLeft: CGPoint
    var hiddenBottomRight: CGPoint
    var hiddenBottomLeft: CGPoint

    init() {
        left = marginHorizontal + width * 0.5
        right = adaptiveScreenWidth - width * 0.5 - marginHorizontal
        bottom = adaptiveScreenHeight - height
        topRight = CGPoint(x: right, y: marginVertical)
        topLeft = CGPoint(x: left, y: marginVertical)
        bottomRight = CGPoint(x: right, y: bottom)
        bottomLeft = CGPoint(x: left, y: bottom)
        hiddenTopRight = CGPoint(x: adaptiveScreenWidth, y: marginVertical)
        hiddenTopLeft = CGPoint(x: 0, y: marginVertical)
        hiddenBottomRight = CGPoint(x: adaptiveScreenWidth, y: bottom)
        hiddenBottomLeft = CGPoint(x: 0, y: bottom)
    }

    mutating func update() {
        right = adaptiveScreenWidth - width * 0.5 - marginHorizontal
        bottom = adaptiveScreenHeight - height
        topRight = CGPoint(x: right, y: marginVertical)
        topLeft = CGPoint(x: left, y: marginVertical)
        bottomRight = CGPoint(x: right, y: bottom)
        bottomLeft = CGPoint(x: left, y: bottom)
        hiddenTopRight = CGPoint(x: adaptiveScreenWidth, y: marginVertical)
        hiddenTopLeft = CGPoint(x: 0, y: marginVertical)
        hiddenBottomRight = CGPoint(x: adaptiveScreenWidth, y: bottom)
        hiddenBottomLeft = CGPoint(x: 0, y: bottom)
    }

    func isHidden(_ position: CGPoint) -> Bool {
        let hiddenPositions: [CGPoint] = [
            hiddenTopLeft,
            hiddenTopRight,
            hiddenBottomLeft,
            hiddenBottomRight
        ]
        return hiddenPositions.contains(position)
    }

    func getToggledPosition(_ position: CGPoint) -> CGPoint {
        if position == topRight {
            return hiddenTopRight
        } else if position == topLeft {
            return hiddenTopLeft
        } else if position == bottomRight {
            return hiddenBottomRight
        } else if position == bottomLeft {
            return hiddenBottomLeft
        } else if position == hiddenTopRight {
            return topRight
        } else if position == hiddenTopLeft {
            return topLeft
        } else if position == hiddenBottomRight {
            return bottomRight
        } else if position == hiddenBottomLeft {
            return bottomLeft
        } else {
            return position
        }
    }

    func toString(_ position: CGPoint) -> String {
        if position == topRight {
            return "topRight"
        } else if position == topLeft {
            return "topLeft"
        } else if position == bottomRight {
            return "bottomRight"
        } else if position == bottomLeft {
            return "bottomLeft"
        } else if position == hiddenTopRight {
            return "hiddenTopRight"
        } else if position == hiddenTopLeft {
            return "hiddenTopLeft"
        } else if position == hiddenBottomRight {
            return "hiddenBottomRight"
        } else if position == hiddenBottomLeft {
            return "hiddenBottomLeft"
        } else {
            return ""
        }
    }

    func fromString(name: String) -> CGPoint {
        if name == "topRight" {
            return topRight
        } else if name == "topLeft" {
            return topLeft
        } else if name == "bottomRight" {
            return bottomRight
        } else if name == "bottomLeft" {
            return bottomLeft
        } else if name == "hiddenTopRight" {
            return hiddenTopRight
        } else if name == "hiddenTopLeft" {
            return hiddenTopLeft
        } else if name == "hiddenBottomRight" {
            return hiddenBottomRight
        } else if name == "hiddenBottomLeft" {
            return hiddenBottomLeft
        } else {
            return topRight
        }
    }
}

struct DragableCaptureView: View {
    @SwiftUI.State private var location: CGPoint = .init(
        x: adaptiveScreenWidth - width * 0.5 - marginHorizontal,
        y: marginVertical
    )
    @GestureState private var currentLocation: CGPoint?
    @GestureState private var startLocation: CGPoint?
    @SwiftUI.State private var positions = DraggablePositions()
    @SwiftUI.State private var alignment: Alignment = .leading
    @SwiftUI.State private var showIndicator: Bool = false
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
            .updating($startLocation) { _, startLocation, _ in
                startLocation = startLocation ?? location
            }
            .onEnded { value in
                let isTop = isTop(value.location)
                let isTrailing = isTrailing(value.location)
                var finalLocation: CGPoint

                switch (isTop, isTrailing) {
                case (false, false):
                    finalLocation = hide ? positions.hiddenBottomLeft : positions.bottomLeft
                case (false, true):
                    finalLocation = hide ? positions.hiddenBottomRight : positions.bottomRight
                case (true, false):
                    finalLocation = hide ? positions.hiddenTopLeft : positions.topLeft
                case (true, true):
                    finalLocation = hide ? positions.hiddenTopRight : positions.topRight
                }
                self.animatePositionChange(to: finalLocation)
            }
    }

    var currentDrag: some Gesture {
        DragGesture()
            .updating($currentLocation) { value, fingerLocation, _ in
                fingerLocation = value.location
            }
    }

    func isOutsideVerticalBounds(_ point: CGPoint) -> Bool {
        return point.y > adaptiveScreenHeight || point.y < 0
    }

    func isOutsideHorizontalBounds(_ point: CGPoint) -> Bool {
        return point.x > adaptiveScreenWidth - (marginHorizontal * 1.5) || point
            .x < marginHorizontal * 1.5
    }

    func isTop(_ point: CGPoint) -> Bool {
        return point.y <= adaptiveScreenHeight / 2
    }

    func isTrailing(_ point: CGPoint) -> Bool {
        return point.x > adaptiveScreenWidth / 2
    }

    var body: some View {
        ZStack {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .cornerRadius(15)
            ZStack(alignment: alignment) {
                VisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterialDark))
                    .opacity(hide ? 1 : 0)
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
            let postion = positions.getToggledPosition(location)
            self.animatePositionChange(to: postion)
        }
        .onReceive(NotificationCenter.default
                    .publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            togglePositionUpdate()
        }
    }

    func togglePositionUpdate() {
        let currentPosition = positions.toString(location)
        positions.update()
        location = positions.fromString(name: currentPosition)
    }

    func animatePositionChange(to newPosition: CGPoint) {
        withAnimation(.dragableCaptureViewAnimation()) {
            self.location = newPosition
            let showIndicator = positions.isHidden(self.location)
            DispatchQueue.main.asyncAfter(deadline: .now() + (showIndicator ? 0.5 : 0)) {
                self.showIndicator = showIndicator
            }
        }
    }
}
