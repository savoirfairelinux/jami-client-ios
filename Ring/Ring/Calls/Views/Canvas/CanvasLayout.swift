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
    let isLocalPreview: Bool

    init(id: String, isLocalPreview: Bool = false) {
        self.id = id
        self.isLocalPreview = isLocalPreview
    }
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

enum CanvasTileStyle: Equatable {
    case plain
    case cards
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
        var edgeToEdgeTileId: String?
    }

    struct Input {
        let participants: [CanvasParticipant]
        let mode: CanvasLayoutMode
        let canvasSize: CGSize
        let safeAreaInsets: UIEdgeInsets
        let previewCorner: PreviewCorner
        let stripOffset: CGFloat
        let style: CanvasTileStyle

        init(participants: [CanvasParticipant],
             mode: CanvasLayoutMode = .grid,
             canvasSize: CGSize,
             safeAreaInsets: UIEdgeInsets = .zero,
             previewCorner: PreviewCorner = .topTrailing,
             stripOffset: CGFloat = 0,
             style: CanvasTileStyle = .plain) {
            self.participants = participants
            self.mode = mode
            self.canvasSize = canvasSize
            self.safeAreaInsets = safeAreaInsets
            self.previewCorner = previewCorner
            self.stripOffset = stripOffset
            self.style = style
        }

        var contentInsets: UIEdgeInsets {
            guard style == .cards else { return .zero }
            return UIEdgeInsets(top: safeAreaInsets.top + CanvasLayout.tileMargin,
                                left: safeAreaInsets.left + CanvasLayout.tileMargin,
                                bottom: safeAreaInsets.bottom + CanvasLayout.tileMargin,
                                right: safeAreaInsets.right + CanvasLayout.tileMargin)
        }

        var gap: CGFloat { style == .cards ? CanvasLayout.tileSpacing : 0 }
    }

    static let basePreviewSize = CGSize(width: 120, height: 170)
    static let previewPadding: CGFloat = 16
    static let previewBottomClearance: CGFloat = 96
    static let tileCornerRadius: CGFloat = 14
    static let tileMargin: CGFloat = 8
    static let tileSpacing: CGFloat = 8
    static let stripPadding: CGFloat = 12
    static let stripSpacing: CGFloat = 8
    static let stripMinimumVisibleTileCount: Int = 2
    static let stripMinimumNextTileVisibleWidth: CGFloat = 24
    static let maximumStripHeightFraction: CGFloat = 1.0 / 3.0
    static let gridRowsPerScreen: Int = 3

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
        let content = contentRect(input)
        let gap = input.gap
        layout.contentSize = input.canvasSize
        layout.zOrder = remote.map(\.id)
        layout.scrollEnabled = false

        switch remote.count {
        case 0:
            break
        case 1:
            layout.frames[remote[0].id] = content
            layout.primaryTileId = remote[0].id
        case 2:
            for (index, participant) in remote.enumerated() {
                layout.frames[participant.id] = cell(row: index, rows: 2,
                                                     column: 0, columns: 1,
                                                     in: content, gap: gap)
            }
        case 3:
            layout.frames[remote[0].id] = cell(row: 0, rows: 2, column: 0, columns: 1,
                                               in: content, gap: gap)
            layout.frames[remote[1].id] = cell(row: 1, rows: 2, column: 0, columns: 2,
                                               in: content, gap: gap)
            layout.frames[remote[2].id] = cell(row: 1, rows: 2, column: 1, columns: 2,
                                               in: content, gap: gap)
        case 4:
            for (index, participant) in remote.enumerated() {
                layout.frames[participant.id] = cell(row: index / 2, rows: 2,
                                                     column: index % 2, columns: 2,
                                                     in: content, gap: gap)
            }
        default:
            for (index, participant) in remote.enumerated() {
                let isLastAndOdd = index == remote.count - 1 && remote.count % 2 == 1
                layout.frames[participant.id] = cell(
                    row: index / 2, rows: gridRowsPerScreen,
                    column: isLastAndOdd ? 0 : index % 2,
                    columns: isLastAndOdd ? 1 : 2,
                    in: content, gap: gap)
            }
            let rowCount = (remote.count + 1) / 2
            let rowHeight = span(content.height, count: gridRowsPerScreen, gap: gap)
            let stackedHeight = CGFloat(rowCount) * rowHeight
                + CGFloat(rowCount - 1) * gap
                + input.contentInsets.top + input.contentInsets.bottom
            let overflows = rowCount > gridRowsPerScreen
            layout.contentSize = CGSize(width: input.canvasSize.width,
                                        height: overflows ? stackedHeight
                                            : input.canvasSize.height)
            layout.scrollEnabled = overflows
        }
        return layout
    }

    private static func span(_ total: CGFloat, count: Int, gap: CGFloat) -> CGFloat {
        (total - CGFloat(count - 1) * gap) / CGFloat(count)
    }

    private static func cell(row: Int, rows: Int, column: Int, columns: Int,
                             in content: CGRect, gap: CGFloat) -> CGRect {
        let width = span(content.width, count: columns, gap: gap)
        let height = span(content.height, count: rows, gap: gap)
        return CGRect(x: content.minX + CGFloat(column) * (width + gap),
                      y: content.minY + CGFloat(row) * (height + gap),
                      width: width, height: height)
    }

    // MARK: - Spotlight & fullscreen

    private static func spotlightLayout(remote: [CanvasParticipant], focusId: String,
                                        input: Input) -> Plan {
        focusedLayout(remote: remote, focusId: focusId, input: input,
                      focusRect: focusFrame(input),
                      stripY: stripBand(input).minY + stripPadding,
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
        let side = stripTileSide(input)
        let stripX = contentRect(input).minX + stripPadding
        for (index, participant) in others.enumerated() {
            layout.frames[participant.id] = CGRect(
                x: stripX + CGFloat(index) * (side + stripSpacing) - input.stripOffset,
                y: stripY,
                width: side, height: side)
        }
        if parksStrip {
            layout.offstage = Set(others.map(\.id))
            layout.edgeToEdgeTileId = focusId
        } else {
            layout.stripContentWidth = stripContentWidth(tileCount: others.count,
                                                         input: input)
        }
        layout.zOrder = others.map(\.id) + [focusId]
        return layout
    }

    // MARK: - Strip geometry

    static func contentRect(_ input: Input) -> CGRect {
        CGRect(origin: .zero, size: input.canvasSize).inset(by: input.contentInsets)
    }

    static func focusFrame(_ input: Input) -> CGRect {
        let content = contentRect(input)
        return CGRect(x: content.minX, y: content.minY,
                      width: content.width,
                      height: content.height - stripBand(input).height)
    }

    static func stripBand(_ input: Input) -> CGRect {
        let content = contentRect(input)
        let height = min(stripTileSide(input) + 2 * stripPadding, content.height)
        return CGRect(x: content.minX, y: content.maxY - height,
                      width: content.width, height: height)
    }

    static func stripTileSide(_ input: Input) -> CGFloat {
        let content = contentRect(input)
        let tallest = content.height * maximumStripHeightFraction - 2 * stripPadding
        let visibleTileCount = CGFloat(stripMinimumVisibleTileCount)
        let widest = (content.width - stripPadding
                        - visibleTileCount * stripSpacing
                        - stripMinimumNextTileVisibleWidth) / visibleTileCount
        return max(min(tallest, widest), 0)
    }

    static func stripContentWidth(tileCount: Int, input: Input) -> CGFloat {
        guard tileCount > 0 else { return 0 }
        return 2 * stripPadding + CGFloat(tileCount) * stripTileSide(input)
            + CGFloat(tileCount - 1) * stripSpacing
    }

    // MARK: - Local preview

    private static func place(preview: CanvasParticipant, into layout: inout Plan,
                              input: Input, remoteCount: Int) {
        if remoteCount == 0 {
            layout.frames[preview.id] = contentRect(input)
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
