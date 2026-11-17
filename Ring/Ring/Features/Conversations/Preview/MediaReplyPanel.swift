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

private enum MediaReplyLayout {
    static let cornerRadius: CGFloat = 34
    static let fieldHeight: CGFloat = 42
    static let fieldFill = Color.white.opacity(0.08)
    static let actionSize: CGFloat = 50
    static let actionWidth: CGFloat = 58
}

struct MediaReplyPanel: View {
    @ObservedObject var model: MediaPreviewModel
    @ObservedObject var panel: MessagePanelVM
    @ObservedObject var voiceRecording: VoiceRecordingVM
    let onSent: () -> Void

    @SwiftUI.State private var text = ""
    @SwiftUI.State private var textHeight: CGFloat = MediaReplyLayout.fieldHeight
    @SwiftUI.State private var isFocused = false
    @Environment(\.dynamicTypeSize)
    private var dynamicTypeSize

    private var isRecording: Bool { voiceRecording.state != .idle }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.bottom, 12)
            if isRecording {
                VoiceRecordingControls(model: voiceRecording)
                    .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(MediaReplyLayout.fieldFill))
            } else {
                if !panel.attachments.isEmpty {
                    DraftAttachmentsView(model: panel)
                        .padding(.bottom, 10)
                }
                if panel.canSendText {
                    field
                }
                if panel.canSendFiles {
                    actions
                        .padding(.top, 16)
                }
            }
        }
        .padding(14)
        .modifier(MediaReplyPanelBackground())
        .onAppear {
            DispatchQueue.main.async { isFocused = panel.canSendText }
        }
        .onChange(of: panel.messageToReply == nil) { ended in
            if ended && model.isReplying {
                onSent()
            }
        }
    }

    private var header: some View {
        Text(L10n.MediaPreview.replyTo(model.title))
            .font(.headline)
            .foregroundColor(.white)
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
            .truncationMode(.middle)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var field: some View {
        HStack(alignment: .bottom, spacing: 0) {
            UITextViewWrapper(withBackground: true,
                              placeholder: L10n.MediaPreview.message,
                              leadingInset: 14,
                              trailingInset: 4,
                              text: $text,
                              isFocused: $isFocused,
                              dynamicHeight: $textHeight)
                .frame(minHeight: textHeight, maxHeight: textHeight)
                .accessibilityLabel(L10n.Accessibility.conversationComposeMessage)
                .onChange(of: text) { newText in
                    panel.handleTyping(message: newText)
                }
            sendButton
        }
        .background(RoundedRectangle(cornerRadius: MediaReplyLayout.fieldHeight / 2, style: .continuous)
                        .fill(MediaReplyLayout.fieldFill))
    }

    private var sendButton: some View {
        Button(action: {
            panel.sendDraft(text: text)
            text = ""
        }, label: {
            Group {
                if panel.isDraftEmpty(text: text) {
                    Text(panel.defaultEmoji)
                        .font(.system(size: 22))
                } else {
                    Image(systemName: "paperplane")
                        .font(.system(size: NavBarIcon.glyphSize))
                        .foregroundColor(.white.opacity(0.85))
                }
            }
            .frame(width: MediaReplyLayout.fieldHeight + 2, height: MediaReplyLayout.fieldHeight)
            .contentShape(Rectangle())
        })
        .buttonStyle(.plain)
        .disabled(panel.isLoadingAttachments)
        .accessibilityLabel(L10n.DataTransfer.sendMessage)
    }

    private var actions: some View {
        HStack(alignment: .top, spacing: 0) {
            action("mic", L10n.MediaPreview.voice) { voiceRecording.start() }
            Spacer(minLength: 0)
            action("video", L10n.MediaPreview.video) { panel.recordVideo() }
            Spacer(minLength: 0)
            action("photo.on.rectangle", L10n.MediaPreview.photos) { panel.openGalery() }
            Spacer(minLength: 0)
            action("doc", L10n.MediaPreview.file) { panel.sendFile() }
        }
    }

    private func action(_ systemName: String, _ title: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            VStack(spacing: 6) {
                Image(systemName: systemName)
                    .font(.system(size: NavBarIcon.glyphSize))
                    .foregroundColor(.white)
                    .frame(width: MediaReplyLayout.actionSize, height: MediaReplyLayout.actionSize)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.1)))
                if !dynamicTypeSize.isAccessibilitySize {
                    Text(title)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.75))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .frame(width: MediaReplyLayout.actionWidth)
            .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
        .accessibilityShowsLargeContentViewer { Label(title, systemImage: systemName) }
    }
}

private struct MediaReplyPanelBackground: ViewModifier {
    private let shape = RoundedRectangle(cornerRadius: MediaReplyLayout.cornerRadius, style: .continuous)

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: shape)
        } else {
            content.background(VisualEffect(style: .systemMaterialDark).clipShape(shape))
        }
    }
}
