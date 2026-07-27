/*
 * Copyright (C) 2019-2026 Savoir-faire Linux Inc.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA.
 */

import UIKit

struct CanvasParticipant: Equatable {
    static let localId = "local"

    let id: String
    var isLocalPreview = false
}

enum CanvasLayoutMode: Equatable {
    case grid
    case spotlight(String)
    case fullscreen(String)

    var focusId: String? {
        switch self {
        case .grid: return nil
        case .spotlight(let id), .fullscreen(let id): return id
        }
    }
}

enum PreviewCorner: CaseIterable {
    case topLeading, topTrailing, bottomLeading, bottomTrailing

    var isTop: Bool { self == .topLeading || self == .topTrailing }
    var isLeading: Bool { self == .topLeading || self == .bottomLeading }
}

enum CanvasLayout {

    struct Plan: Equatable {
        var frames: [String: CGRect] = [:]
        var contentSize: CGSize = .zero
        var zOrder: [String] = []
        var scrollEnabled = true
        var stripContentWidth: CGFloat = 0
        var offstage: Set<String> = []
        var primaryTileId: String?
    }

    struct Input {
        var participants: [CanvasParticipant]
        var mode: CanvasLayoutMode = .grid
        var canvasSize: CGSize
        var safeAreaInsets: UIEdgeInsets = .zero
        var previewCorner: PreviewCorner = .topTrailing
        var stripOffset: CGFloat = 0
    }

    static let basePreviewSize = CGSize(width: 120, height: 170)
    static let previewPadding: CGFloat = 16
    static let previewBottomClearance: CGFloat = 96
    static let previewCornerRadius: CGFloat = 14
    static let spotlightFocusFraction: CGFloat = 2.0 / 3.0
    static let stripPadding: CGFloat = 12
    static let stripSpacing: CGFloat = 8

    static func plan(_ input: Input) -> Plan {
        let remote = input.participants.filter { !$0.isLocalPreview }
        let preview = input.participants.first { $0.isLocalPreview }

        var layout: Plan
        switch input.mode {
        case .grid:
            layout = gridLayout(remote: remote, input: input)
        case .spotlight(let focusId):
            layout = spotlightLayout(remote: remote, focusId: focusId, input: input)
        case .fullscreen(let focusId):
            layout = fullscreenLayout(remote: remote, focusId: focusId, input: input)
        }

        if let preview = preview {
            place(preview: preview, into: &layout, input: input, remoteCount: remote.count)
        }
        return layout
    }

    static func shouldRenderVideo(frame: CGRect, visibleRect: CGRect,
                                  margin: CGFloat) -> Bool {
        return frame.intersects(visibleRect.insetBy(dx: 0, dy: -margin))
    }

    // MARK: - Grid

    private static func gridLayout(remote: [CanvasParticipant], input: Input) -> Plan {
        var layout = Plan()
        let size = input.canvasSize
        layout.contentSize = size
        layout.zOrder = remote.map(\.id)
        layout.scrollEnabled = false

        switch remote.count {
        case 0:
            break
        case 1:
            layout.frames[remote[0].id] = CGRect(origin: .zero, size: size)
            layout.primaryTileId = remote[0].id
        case 2:
            let half = CGSize(width: size.width, height: size.height / 2)
            layout.frames[remote[0].id] = CGRect(origin: .zero, size: half)
            layout.frames[remote[1].id] = CGRect(x: 0, y: half.height,
                                                 width: half.width, height: half.height)
        case 3:
            let rowHeight = size.height / 2
            layout.frames[remote[0].id] = CGRect(x: 0, y: 0,
                                                 width: size.width, height: rowHeight)
            layout.frames[remote[1].id] = CGRect(x: 0, y: rowHeight,
                                                 width: size.width / 2, height: rowHeight)
            layout.frames[remote[2].id] = CGRect(x: size.width / 2, y: rowHeight,
                                                 width: size.width / 2, height: rowHeight)
        case 4:
            let tile = CGSize(width: size.width / 2, height: size.height / 2)
            for (index, participant) in remote.enumerated() {
                layout.frames[participant.id] = CGRect(
                    x: CGFloat(index % 2) * tile.width,
                    y: CGFloat(index / 2) * tile.height,
                    width: tile.width, height: tile.height)
            }
        default:
            let rowHeight = size.height / 3
            let halfWidth = size.width / 2
            for (index, participant) in remote.enumerated() {
                let row = CGFloat(index / 2)
                let isLastAndOdd = index == remote.count - 1 && remote.count % 2 == 1
                layout.frames[participant.id] = CGRect(
                    x: isLastAndOdd ? 0 : CGFloat(index % 2) * halfWidth,
                    y: row * rowHeight,
                    width: isLastAndOdd ? size.width : halfWidth,
                    height: rowHeight)
            }
            let rows = CGFloat((remote.count + 1) / 2)
            layout.contentSize = CGSize(width: size.width,
                                        height: max(rows * rowHeight, size.height))
            layout.scrollEnabled = rows * rowHeight > size.height
        }
        return layout
    }

    // MARK: - Spotlight & fullscreen

    private static func spotlightLayout(remote: [CanvasParticipant], focusId: String,
                                        input: Input) -> Plan {
        focusedLayout(remote: remote, focusId: focusId, input: input,
                      focusRect: focusFrame(canvasSize: input.canvasSize),
                      stripY: input.canvasSize.height * spotlightFocusFraction
                        + stripPadding,
                      parksStrip: false)
    }

    private static func fullscreenLayout(remote: [CanvasParticipant], focusId: String,
                                         input: Input) -> Plan {
        focusedLayout(remote: remote, focusId: focusId, input: input,
                      focusRect: CGRect(origin: .zero, size: input.canvasSize),
                      stripY: input.canvasSize.height + stripPadding,
                      parksStrip: true)
    }

    private static func focusedLayout(remote: [CanvasParticipant], focusId: String,
                                      input: Input, focusRect: CGRect,
                                      stripY: CGFloat, parksStrip: Bool) -> Plan {
        guard remote.contains(where: { $0.id == focusId }) else {
            return gridLayout(remote: remote, input: input)
        }
        var layout = Plan()
        layout.contentSize = input.canvasSize
        layout.scrollEnabled = false
        layout.frames[focusId] = focusRect
        layout.primaryTileId = focusId

        let others = remote.filter { $0.id != focusId }
        let side = stripTileSide(canvasSize: input.canvasSize)
        for (index, participant) in others.enumerated() {
            layout.frames[participant.id] = CGRect(
                x: stripTileX(index: index, side: side) - input.stripOffset,
                y: stripY,
                width: side, height: side)
        }
        if parksStrip {
            layout.offstage = Set(others.map(\.id))
        } else {
            layout.stripContentWidth = stripContentWidth(tileCount: others.count,
                                                         canvasSize: input.canvasSize)
        }
        layout.zOrder = others.map(\.id) + [focusId]
        return layout
    }

    // MARK: - Strip geometry

    static func focusFrame(canvasSize: CGSize) -> CGRect {
        CGRect(x: 0, y: 0, width: canvasSize.width,
               height: canvasSize.height * spotlightFocusFraction)
    }

    static func stripBand(canvasSize: CGSize) -> CGRect {
        let top = canvasSize.height * spotlightFocusFraction
        return CGRect(x: 0, y: top,
                      width: canvasSize.width, height: canvasSize.height - top)
    }

    static func stripTileSide(canvasSize: CGSize) -> CGFloat {
        max(stripBand(canvasSize: canvasSize).height - 2 * stripPadding, 0)
    }

    static func stripContentWidth(tileCount: Int, canvasSize: CGSize) -> CGFloat {
        guard tileCount > 0 else { return 0 }
        let side = stripTileSide(canvasSize: canvasSize)
        return 2 * stripPadding + CGFloat(tileCount) * side
            + CGFloat(tileCount - 1) * stripSpacing
    }

    private static func stripTileX(index: Int, side: CGFloat) -> CGFloat {
        stripPadding + CGFloat(index) * (side + stripSpacing)
    }

    // MARK: - Local preview

    private static func place(preview: CanvasParticipant, into layout: inout Plan,
                              input: Input, remoteCount: Int) {
        if remoteCount == 0 {
            layout.frames[preview.id] = CGRect(origin: .zero, size: input.canvasSize)
            layout.contentSize = input.canvasSize
            layout.zOrder.append(preview.id)
            layout.scrollEnabled = false
            layout.primaryTileId = preview.id
            return
        }
        let origin = previewOrigin(for: input.previewCorner,
                                   in: CGRect(origin: .zero, size: input.canvasSize),
                                   safeAreaInsets: input.safeAreaInsets)
        layout.frames[preview.id] = CGRect(origin: origin,
                                           size: previewSize(for: input.canvasSize))
        layout.zOrder.append(preview.id)
    }

    static func previewSize(for canvasSize: CGSize) -> CGSize {
        canvasSize.width > canvasSize.height
            ? CGSize(width: basePreviewSize.height, height: basePreviewSize.width)
            : basePreviewSize
    }

    static func previewOrigin(for corner: PreviewCorner,
                              in bounds: CGRect,
                              safeAreaInsets: UIEdgeInsets) -> CGPoint {
        let size = previewSize(for: bounds.size)
        let originX = corner.isLeading
            ? bounds.minX + safeAreaInsets.left + previewPadding
            : bounds.maxX - size.width - previewPadding - safeAreaInsets.right
        let originY = corner.isTop
            ? bounds.minY + safeAreaInsets.top + previewPadding
            : bounds.maxY - size.height - previewPadding
            - safeAreaInsets.bottom - previewBottomClearance
        return CGPoint(x: originX, y: originY)
    }
}
