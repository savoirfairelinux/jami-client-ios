/*
 *  Copyright (C) 2026-2026 Savoir-faire Linux Inc.
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

private enum AttachmentSheetStyle {
    static let accent = Color(UIColor.jami)
    static let controlFill = Color(UIColor.tertiarySystemFill)
    static let placeholderFill = Color(UIColor.secondarySystemBackground)
    static let secondaryText = Color(UIColor.secondaryLabel)
    static let overlayText = Color.white
    static let overlayScrim = Color.black.opacity(0.45)
    static let tapTarget: CGFloat = 44
}

struct AttachmentSheetView: View {
    @ObservedObject var model: AttachmentSheetVM
    let panel: MessagePanelVM

    var body: some View {
        VStack(spacing: 0) {
            header
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            if !model.selection.isEmpty {
                AttachmentSendPanel(model: model, panel: panel)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(Color(UIColor.systemBackground).ignoresSafeArea())
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: model.selection.isEmpty)
        .onAppear(perform: model.onAppear)
    }

    private var header: some View {
        HStack(spacing: 0) {
            Button(action: { model.perform(.close) }, label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .foregroundColor(AttachmentSheetStyle.secondaryText)
                    .frame(width: AttachmentSheetStyle.tapTarget, height: AttachmentSheetStyle.tapTarget)
            })
            .accessibilityLabel(L10n.Global.close)
            Spacer()
            Text(model.title)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Color.clear
                .frame(width: AttachmentSheetStyle.tapTarget, height: AttachmentSheetStyle.tapTarget)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 8)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    @ViewBuilder private var content: some View {
        switch model.access {
        case .notDetermined:
            ProgressView()
        case .denied:
            AttachmentAccessDeniedView(model: model)
        case .full, .limited:
            AttachmentGrid(model: model)
        }
    }
}

private struct AttachmentGrid: View {
    @ObservedObject var model: AttachmentSheetVM
    let spacing: CGFloat = 2

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: spacing), count: 3)
    }

    var body: some View {
        ScrollView {
            if model.access == .limited {
                AttachmentLimitedAccessBanner(model: model)
            }
            LazyVGrid(columns: columns, spacing: spacing) {
                if !model.showsSelectionOnly {
                    AttachmentCameraTile {
                        model.perform(.takePhoto)
                    }
                }
                ForEach(0..<model.visibleItems.count, id: \.self) { index in
                    let item = model.visibleItems.item(at: index)
                    AttachmentMediaCell(item: item, isSelected: model.isSelected(item), model: model)
                        .id(item.id)
                }
                if model.access == .limited && !model.showsSelectionOnly {
                    AttachmentAddMoreTile {
                        model.perform(.manageLimitedAccess)
                    }
                }
            }
            if model.items.isEmpty {
                Text(L10n.AttachmentSheet.empty)
                    .font(.subheadline)
                    .foregroundColor(AttachmentSheetStyle.secondaryText)
                    .padding(.top, 24)
            }
        }
    }
}

private struct AttachmentThumbnail: View {
    let item: GalleryItem
    let model: AttachmentSheetVM
    @SwiftUI.State private var image: UIImage?
    @SwiftUI.State private var cancelRequest: (() -> Void)?
    @Environment(\.displayScale)
    private var displayScale

    var body: some View {
        GeometryReader { proxy in
            AttachmentSheetStyle.placeholderFill
                .overlay(image.map { Image(uiImage: $0).resizable().scaledToFill() })
                .clipped()
                .onAppear {
                    load(size: proxy.size)
                }
        }
        .onDisappear {
            cancelRequest?()
            cancelRequest = nil
        }
    }

    private func load(size: CGSize) {
        guard image == nil, cancelRequest == nil else { return }
        let pixelSize = CGSize(width: size.width * displayScale, height: size.height * displayScale)
        cancelRequest = model.thumbnail(for: item, pixelSize: pixelSize) { image = $0 }
    }
}

private struct AttachmentKindBadge: View {
    let item: GalleryItem

    var body: some View {
        switch item.kind {
        case .video:
            badge {
                Image(systemName: "video.fill")
                Text(AttachmentSheetVM.durationText(item.duration))
            }
        case .gif:
            badge {
                Text(L10n.AttachmentSheet.gif)
            }
        case .image:
            EmptyView()
        }
    }

    private func badge<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 3, content: content)
            .font(.caption2.weight(.semibold))
            .foregroundColor(AttachmentSheetStyle.overlayText)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Capsule().fill(AttachmentSheetStyle.overlayScrim))
            .padding(5)
            .accessibilityHidden(true)
    }
}

private struct AttachmentSelectionIndicator: View {
    let isSelected: Bool
    let size: CGFloat = 24

    var body: some View {
        ZStack {
            if isSelected {
                Circle()
                    .fill(AttachmentSheetStyle.accent)
                Image(systemName: "checkmark")
                    .font(.caption.weight(.bold))
                    .foregroundColor(AttachmentSheetStyle.overlayText)
                    .transition(.scale)
            } else {
                Circle()
                    .fill(Color.black.opacity(0.15))
                Circle()
                    .strokeBorder(AttachmentSheetStyle.overlayText, lineWidth: 1.5)
            }
        }
        .frame(width: size, height: size)
        .shadow(color: Color.black.opacity(0.2), radius: 2)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
    }
}

private struct AttachmentMediaCell: View {
    let item: GalleryItem
    let isSelected: Bool
    let model: AttachmentSheetVM

    var body: some View {
        AttachmentThumbnail(item: item, model: model)
            .aspectRatio(1, contentMode: .fit)
            .overlay(Color.black.opacity(isSelected ? 0.2 : 0))
            .overlay(AttachmentKindBadge(item: item), alignment: .bottomLeading)
            .overlay(AttachmentSelectionIndicator(isSelected: isSelected).padding(6), alignment: .topTrailing)
            .contentShape(Rectangle())
            .onTapGesture {
                model.toggle(item)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(model.accessibilityLabel(for: item))
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

private struct AttachmentCameraTile: View {
    let action: () -> Void

    var body: some View {
        Button(action: action, label: {
            AttachmentSheetStyle.placeholderFill
                .aspectRatio(1, contentMode: .fit)
                .overlay(
                    VStack(spacing: 6) {
                        Image(systemName: "camera.fill")
                            .font(.title2)
                        Text(L10n.AttachmentSheet.camera)
                            .font(.footnote)
                    }
                    .foregroundColor(AttachmentSheetStyle.secondaryText)
                )
        })
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.AttachmentSheet.camera)
    }
}

private struct AttachmentAddMoreTile: View {
    let action: () -> Void

    var body: some View {
        Button(action: action, label: {
            Color(UIColor.systemBackground)
                .aspectRatio(1, contentMode: .fit)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(Color(UIColor.separator), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                )
                .overlay(
                    VStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.title2)
                        Text(L10n.AttachmentSheet.addMore)
                            .font(.footnote.weight(.semibold))
                            .multilineTextAlignment(.center)
                    }
                    .foregroundColor(AttachmentSheetStyle.accent)
                    .padding(6)
                )
        })
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.AttachmentSheet.addMore)
    }
}

private struct AttachmentLimitedAccessBanner: View {
    let model: AttachmentSheetVM

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .foregroundColor(AttachmentSheetStyle.secondaryText)
                .accessibilityHidden(true)
            Text(L10n.AttachmentSheet.limitedAccess)
                .font(.footnote)
                .foregroundColor(AttachmentSheetStyle.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button(L10n.AttachmentSheet.manage) {
                model.perform(.manageLimitedAccess)
            }
            .font(.footnote.weight(.semibold))
            .foregroundColor(AttachmentSheetStyle.accent)
            .frame(minHeight: AttachmentSheetStyle.tapTarget)
        }
        .padding(.horizontal, 12)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AttachmentSheetStyle.controlFill))
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }
}

private struct AttachmentAccessDeniedView: View {
    let model: AttachmentSheetVM

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 44, weight: .light))
                    .foregroundColor(AttachmentSheetStyle.secondaryText)
                    .accessibilityHidden(true)
                Text(L10n.AttachmentSheet.noAccessTitle)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                Text(L10n.AttachmentSheet.noAccessMessage)
                    .font(.subheadline)
                    .foregroundColor(AttachmentSheetStyle.secondaryText)
                    .multilineTextAlignment(.center)
                Button(action: { model.perform(.openSettings) }, label: {
                    Text(L10n.Actions.goToSettings)
                        .font(.body.weight(.semibold))
                        .frame(minHeight: AttachmentSheetStyle.tapTarget)
                        .padding(.horizontal, 12)
                })
                .buttonStyle(.borderedProminent)
                .tint(AttachmentSheetStyle.accent)
                .padding(.top, 6)
                Button(action: { model.perform(.browseAllPhotos) }, label: {
                    Text(L10n.AttachmentSheet.browsePhotos)
                        .font(.body)
                        .frame(minHeight: AttachmentSheetStyle.tapTarget)
                })
                .foregroundColor(AttachmentSheetStyle.accent)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
        }
    }
}

private struct AttachmentSendPanel: View {
    @ObservedObject var model: AttachmentSheetVM
    @ObservedObject var panel: MessagePanelVM
    let quoteCornerRadius: CGFloat = 21

    var body: some View {
        VStack(spacing: 6) {
            if panel.messageToReply != nil, let quote = panel.quote {
                ComposerQuoteView(quote: quote,
                                  title: nil,
                                  accent: panel.quoteAccent,
                                  textColor: panel.styling.textColor,
                                  containerCornerRadius: quoteCornerRadius,
                                  cancel: panel.cancelReply)
                    .id(ObjectIdentifier(quote))
            }
            HStack(spacing: 12) {
                Button(action: model.toggleSelectionOnly, label: {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(model.summary)
                            .font(.body.weight(.semibold))
                            .foregroundColor(Color(UIColor.label))
                        Text(model.showsSelectionOnly ? L10n.AttachmentSheet.showAll : L10n.AttachmentSheet.showSelected)
                            .font(.footnote)
                            .foregroundColor(AttachmentSheetStyle.accent)
                    }
                    .frame(maxWidth: .infinity, minHeight: AttachmentSheetStyle.tapTarget, alignment: .leading)
                    .contentShape(Rectangle())
                })
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(model.summary)
                .accessibilityHint(model.showsSelectionOnly ? L10n.AttachmentSheet.showAll : L10n.AttachmentSheet.showSelected)
                Button(action: model.send, label: {
                    HStack(spacing: 7) {
                        Text(L10n.AttachmentSheet.send(model.selection.count))
                            .font(.body.weight(.semibold))
                        Image(systemName: "paperplane.fill")
                            .font(.subheadline.weight(.semibold))
                            .accessibilityHidden(true)
                    }
                    .foregroundColor(AttachmentSheetStyle.overlayText)
                    .padding(.horizontal, 18)
                    .frame(minHeight: AttachmentSheetStyle.tapTarget)
                    .background(Capsule().fill(AttachmentSheetStyle.accent))
                })
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(AttachmentBarBackground())
    }
}

private struct AttachmentBarBackground: View {
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            Rectangle()
                .fill(.bar)
        }
        .ignoresSafeArea(edges: .bottom)
    }
}
