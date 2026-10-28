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

    var body: some View {
        VStack(spacing: 0) {
            header
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            if model.selection.isEmpty {
                AttachmentSourceBar(model: model)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                AttachmentSendPanel(model: model)
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
                AttachmentCameraTile {
                    model.perform(.takePhoto)
                }
                ForEach(0..<model.items.count, id: \.self) { index in
                    let item = model.items.item(at: index)
                    AttachmentMediaCell(item: item, number: model.selectionNumber(of: item), model: model)
                        .id(item.id)
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
    let number: Int?
    let size: CGFloat = 24

    var body: some View {
        ZStack {
            if let number = number {
                Circle()
                    .fill(AttachmentSheetStyle.accent)
                Text("\(number)")
                    .font(.footnote.weight(.bold))
                    .foregroundColor(AttachmentSheetStyle.overlayText)
                    .minimumScaleFactor(0.6)
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
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: number)
    }
}

private struct AttachmentMediaCell: View {
    let item: GalleryItem
    let number: Int?
    let model: AttachmentSheetVM

    var body: some View {
        AttachmentThumbnail(item: item, model: model)
            .aspectRatio(1, contentMode: .fit)
            .overlay(Color.black.opacity(number == nil ? 0 : 0.2))
            .overlay(AttachmentKindBadge(item: item), alignment: .bottomLeading)
            .overlay(AttachmentSelectionIndicator(number: number).padding(6), alignment: .topTrailing)
            .contentShape(Rectangle())
            .onTapGesture {
                model.toggle(item)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(model.accessibilityLabel(for: item))
            .accessibilityValue(number.map { L10n.Accessibility.attachmentSheetSelected($0) } ?? "")
            .accessibilityAddTraits(number == nil ? .isButton : [.isButton, .isSelected])
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

private struct AttachmentSourceBar: View {
    let model: AttachmentSheetVM

    var body: some View {
        HStack(spacing: 0) {
            source(L10n.AttachmentSheet.title, systemImage: "photo.fill", isCurrent: true) {}
            source(L10n.AttachmentSheet.file, systemImage: "doc.fill", isCurrent: false) {
                model.perform(.pickFile)
            }
            source(L10n.AttachmentSheet.location, systemImage: "location.fill", isCurrent: false) {
                model.perform(.shareLocation)
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(AttachmentBarBackground())
    }

    private func source(_ title: String, systemImage: String, isCurrent: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action, label: {
            VStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.body.weight(.semibold))
                    .foregroundColor(isCurrent ? AttachmentSheetStyle.overlayText : AttachmentSheetStyle.accent)
                    .frame(width: AttachmentSheetStyle.tapTarget, height: AttachmentSheetStyle.tapTarget)
                    .background(Circle().fill(isCurrent ? AttachmentSheetStyle.accent : AttachmentSheetStyle.controlFill))
                Text(title)
                    .font(.caption)
                    .foregroundColor(isCurrent ? AttachmentSheetStyle.accent : AttachmentSheetStyle.secondaryText)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        })
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isCurrent ? [.isButton, .isSelected] : .isButton)
    }
}

private struct AttachmentSendPanel: View {
    @ObservedObject var model: AttachmentSheetVM

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            summary
            selectedStrip
            if let replyName = model.replyName {
                Label(L10n.AttachmentSheet.replyTo(replyName), systemImage: "arrowshape.turn.up.left")
                    .font(.footnote)
                    .foregroundColor(AttachmentSheetStyle.secondaryText)
                    .lineLimit(1)
            }
            HStack(spacing: 10) {
                TextField(L10n.AttachmentSheet.captionPlaceholder, text: $model.caption)
                    .padding(.horizontal, 14)
                    .frame(minHeight: AttachmentSheetStyle.tapTarget)
                    .background(Capsule().fill(AttachmentSheetStyle.controlFill))
                    .submitLabel(.send)
                    .onSubmit(model.send)
                sendButton
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(AttachmentBarBackground())
    }

    private var summary: some View {
        HStack(spacing: 12) {
            if model.photoCount > 0 {
                Label("\(model.photoCount)", systemImage: "photo")
                    .accessibilityLabel(L10n.Accessibility.attachmentSheetPhotos(model.photoCount))
            }
            if model.videoCount > 0 {
                Label("\(model.videoCount)", systemImage: "video")
                    .accessibilityLabel(L10n.Accessibility.attachmentSheetVideos(model.videoCount))
            }
            Spacer()
            Button(L10n.AttachmentSheet.clear, action: model.clearSelection)
                .font(.subheadline)
                .foregroundColor(AttachmentSheetStyle.accent)
                .frame(minHeight: AttachmentSheetStyle.tapTarget)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundColor(AttachmentSheetStyle.secondaryText)
        .accessibilityElement(children: .contain)
    }

    private var selectedStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(model.selection.enumerated()), id: \.element.id) { index, item in
                    AttachmentSelectedThumbnail(item: item, number: index + 1, model: model)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.top, 8)
            .padding(.trailing, 8)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: model.selection.map(\.id))
        }
    }

    private var sendButton: some View {
        Button(action: model.send, label: {
            Image(systemName: "paperplane.fill")
                .font(.body.weight(.semibold))
                .foregroundColor(AttachmentSheetStyle.overlayText)
                .frame(width: AttachmentSheetStyle.tapTarget, height: AttachmentSheetStyle.tapTarget)
                .background(Circle().fill(AttachmentSheetStyle.accent))
                .overlay(countBadge, alignment: .topTrailing)
        })
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.Accessibility.attachmentSheetSend(model.selection.count))
    }

    private var countBadge: some View {
        Text("\(model.selection.count)")
            .font(.caption2.weight(.bold))
            .foregroundColor(AttachmentSheetStyle.accent)
            .padding(.horizontal, 5)
            .frame(minWidth: 20, minHeight: 20)
            .background(Capsule().fill(Color(UIColor.systemBackground)))
            .overlay(Capsule().strokeBorder(AttachmentSheetStyle.accent, lineWidth: 1.5))
            .offset(x: 6, y: -6)
    }
}

private struct AttachmentSelectedThumbnail: View {
    let item: GalleryItem
    let number: Int
    let model: AttachmentSheetVM
    let size: CGFloat = 56
    let removeIconSize: CGFloat = 20

    var body: some View {
        AttachmentThumbnail(item: item, model: model)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(kindIcon, alignment: .bottomLeading)
            .overlay(numberBadge, alignment: .bottomTrailing)
            .overlay(removeButton, alignment: .topTrailing)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(model.accessibilityLabel(for: item))
            .accessibilityValue(L10n.Accessibility.attachmentSheetSelected(number))
            .accessibilityAction(named: L10n.Global.remove) {
                model.toggle(item)
            }
    }

    @ViewBuilder private var kindIcon: some View {
        if item.kind == .video {
            Image(systemName: "video.fill")
                .font(.caption2)
                .foregroundColor(AttachmentSheetStyle.overlayText)
                .shadow(color: Color.black.opacity(0.4), radius: 1)
                .padding(5)
        }
    }

    private var numberBadge: some View {
        Text("\(number)")
            .font(.caption2.weight(.bold))
            .foregroundColor(AttachmentSheetStyle.overlayText)
            .frame(minWidth: 18, minHeight: 18)
            .background(Circle().fill(AttachmentSheetStyle.accent))
            .padding(3)
    }

    private var removeButton: some View {
        Button(action: { model.toggle(item) }, label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: removeIconSize))
                .foregroundStyle(Color(UIColor.systemBackground), Color(UIColor.label))
                .frame(width: AttachmentSheetStyle.tapTarget, height: AttachmentSheetStyle.tapTarget)
                .contentShape(Rectangle())
        })
        .buttonStyle(.plain)
        .offset(x: (AttachmentSheetStyle.tapTarget - removeIconSize) / 2,
                y: -(AttachmentSheetStyle.tapTarget - removeIconSize) / 2)
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
