/*
 *  Copyright (C) 2024 Savoir-faire Linux Inc.
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

struct ComposerQuoteView: View {
    @ObservedObject var quote: MessageReplyTargetVM
    let title: String?
    let accent: Color
    let textColor: Color
    let containerCornerRadius: CGFloat
    let cancel: () -> Void

    private let containerInset: CGFloat = 6
    private let cardInset = EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8)
    private let closeIconSize: CGFloat = 26
    private let closeTargetSize: CGFloat = 44

    var body: some View {
        if let line = quote.line {
            HStack(spacing: 0) {
                ReplyQuoteFrame(accent: accent, isHighlighted: false) {
                    ReplyQuoteLabel(title: title ?? quote.authorName, line: line, thumbnail: quote.thumbnail, accent: accent, textColor: textColor)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(cardInset)
                .background(RoundedRectangle(cornerRadius: containerCornerRadius - containerInset, style: .continuous)
                                .fill(Color(UIColor.tertiarySystemFill)))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityLabel(line: line))
                closeButton
            }
            .padding(.top, containerInset)
            .padding(.leading, containerInset)
            .onAppear {
                quote.onQuoteAppear()
            }
        }
    }

    private var closeButton: some View {
        Button(action: cancel, label: {
            Image(systemName: "xmark")
                .font(.footnote.weight(.semibold))
                .foregroundColor(Color(UIColor.secondaryLabel))
                .frame(width: closeIconSize, height: closeIconSize)
                .background(Circle().fill(Color(UIColor.tertiarySystemFill)))
                .frame(width: closeTargetSize, height: closeTargetSize)
                .contentShape(Rectangle())
        })
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.Global.cancel)
    }

    private func accessibilityLabel(line: ReplyQuoteLine) -> String {
        let heading = title ?? L10n.Conversation.inReplyTo + " " + quote.authorName
        return heading + ": " + line.text
    }
}

struct DraftAttachmentView: View {
    let attachment: DraftAttachment
    let remove: () -> Void
    let size = DraftAttachment.thumbnailSize
    let cornerRadius: CGFloat = 10
    let removeIconSize: CGFloat = 20
    let removeTargetSize: CGFloat = 44

    var body: some View {
        content
            .frame(width: size, height: size)
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(statusOverlay)
            .overlay(removeButton, alignment: .topTrailing)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityAction(named: L10n.Global.remove, remove)
    }

    @ViewBuilder private var content: some View {
        if let thumbnail = attachment.thumbnail {
            Image(uiImage: thumbnail)
                .resizable()
                .scaledToFill()
        } else {
            VStack(spacing: 4) {
                Image(systemName: attachment.kind == .video ? "film" : "doc")
                    .font(.title3)
                Text(attachment.displayName)
                    .font(.caption2)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .foregroundColor(Color(UIColor.secondaryLabel))
            .padding(4)
        }
    }

    @ViewBuilder private var statusOverlay: some View {
        switch attachment.status {
        case .loading:
            ProgressView()
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundColor(Color(UIColor.systemRed))
        case .ready:
            EmptyView()
        }
    }

    private var removeButton: some View {
        Button(action: remove, label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: removeIconSize))
                .foregroundStyle(Color(UIColor.systemBackground), Color(UIColor.label))
                .frame(width: removeTargetSize, height: removeTargetSize)
                .contentShape(Rectangle())
        })
        .buttonStyle(.plain)
        .offset(x: (removeTargetSize - removeIconSize) / 2, y: -(removeTargetSize - removeIconSize) / 2)
    }

    private var accessibilityLabel: String {
        switch attachment.status {
        case .loading:
            return L10n.Accessibility.draftAttachmentLoading(attachment.displayName)
        case .failed:
            return L10n.Accessibility.draftAttachmentFailed(attachment.displayName)
        case .ready:
            return attachment.displayName
        }
    }
}

struct DraftAttachmentsView: View {
    @ObservedObject var model: MessagePanelVM
    let spacing: CGFloat = 10
    let badgeInset: CGFloat = 12

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: spacing) {
                ForEach(model.attachments) { attachment in
                    DraftAttachmentView(attachment: attachment) {
                        model.removeAttachment(attachment)
                    }
                }
            }
            .padding(.top, badgeInset)
            .padding(.trailing, badgeInset)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct MessagePanelView: View {
    @ObservedObject var model: MessagePanelVM
    @ObservedObject var voiceRecording: VoiceRecordingVM
    @Binding var isFocused: Bool
    @SwiftUI.State private var text: String = ""
    @SwiftUI.State private var textHeight: CGFloat = 42
    let padding: CGFloat = 10
    let defaultControlSize: CGFloat = 42
    let paddingGorizontal: CGFloat = 20
    let textContainerLeadingInset: CGFloat = 14
    let sendIconSize: CGFloat = 25

    private var buttonVisualSidePadding: CGFloat {
        (defaultControlSize - sendIconSize) / 2
    }

    private var compactTextInputInset: CGFloat {
        max(0, textContainerLeadingInset - buttonVisualSidePadding)
    }

    struct MessagePanelImageButton: View {
        let model: MessagePanelVM
        let systemName: String
        let width: CGFloat
        let height: CGFloat

        var body: some View {
            Image(systemName: systemName)
                .resizable()
                .font(Font.title.weight(.light))
                .imageScale(.small)
                .scaledToFit()
                .padding(.horizontal, 9)
                .padding(.top, 13)
                .padding(.bottom, 5)
                .frame(width: width, height: height)
                .foregroundColor(model.styling.secondaryTextColor)
        }
    }

    @ViewBuilder
    private func moreActionsButton() -> some View {
        Menu(content: menuContent, label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .light))
                .foregroundColor(model.styling.secondaryTextColor)
                .messagePanelControlBackground(size: defaultControlSize)
        })
        .accessibilityLabel(L10n.Accessibility.conversationShareMedia)
        .accessibilityRemoveTraits(.isButton)
        .disabled(model.messageToEdit != nil || voiceRecording.state != .idle)
    }

    @ViewBuilder
    private func composerField() -> some View {
        VStack(spacing: 0) {
            composerQuote()
            if !model.attachments.isEmpty {
                DraftAttachmentsView(model: model)
                    .padding(.leading, textContainerLeadingInset)
            }
            if voiceRecording.state == .idle {
                messageTextRow()
            } else {
                VoiceRecordingControls(model: voiceRecording)
            }
        }
        .messagePanelGlass(in: RoundedRectangle(cornerRadius: defaultControlSize / 2))
    }

    @ViewBuilder
    private func composerQuote() -> some View {
        if let quote = model.quote {
            ComposerQuoteView(quote: quote,
                              title: model.messageToEdit == nil ? nil : L10n.Global.editMessage,
                              accent: model.quoteAccent,
                              textColor: model.styling.textColor,
                              containerCornerRadius: defaultControlSize / 2,
                              cancel: cancelQuote)
        }
    }

    private func cancelQuote() {
        if model.messageToEdit != nil {
            model.cancelEdit()
        } else {
            model.cancelReply()
        }
    }

    @ViewBuilder
    private func messageTextRow() -> some View {
        HStack(alignment: .center, spacing: 0) {
            UITextViewWrapper(
                withBackground: true,
                placeholder: model.placeholder,
                leadingInset: textContainerLeadingInset,
                trailingInset: compactTextInputInset,
                text: $text,
                isFocused: $isFocused,
                dynamicHeight: $textHeight
            )
            .frame(minHeight: textHeight, maxHeight: textHeight)
            .accessibilityLabel(L10n.Accessibility.conversationComposeMessage)
            .onChange(of: text) { _ in
                model.handleTyping(message: text)
            }

            sendEmojiButton()
                .padding(.trailing, compactTextInputInset)
        }
    }

    @ViewBuilder
    private func sendEmojiButton() -> some View {
        Button(action: {
            self.model.sendDraft(text: text)
            text = ""
        }, label: {
            ZStack {
                if model.isDraftEmpty(text: text) {
                    Text(model.defaultEmoji)
                        .font(.system(size: 26))
                        .bold()
                } else {
                    Image(systemName: "paperplane")
                        .resizable()
                        .frame(width: sendIconSize, height: sendIconSize)
                        .foregroundColor(model.styling.secondaryTextColor)
                }
            }
            .frame(width: defaultControlSize, height: defaultControlSize)
            .contentShape(Rectangle())
        })
        .buttonStyle(.plain)
        .disabled(model.isLoadingAttachments)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: text.isEmpty)
    }

    var body: some View {
        VStack(spacing: 0) {
            if let hint = voiceRecording.hint {
                VoiceRecordingHint(text: hint)
                    .padding(.top, padding)
            }

            Group {
                if voiceRecording.state == .idle || model.messageToReply != nil {
                    HStack(alignment: .bottom, spacing: textContainerLeadingInset) {
                        moreActionsButton()
                        composerField()
                    }
                } else {
                    VoiceRecordingPanel(model: voiceRecording)
                }
            }
            .padding(.top, padding)
            .padding(.bottom, isFocused ? padding : 0)
        }
        .onChange(of: model.isEdit) { _ in
            isFocused = model.isEdit
        }
        .onChange(of: model.messageToEdit?.message.id) { _ in
            text = model.messageToEdit?.content ?? ""
        }
        .padding(.horizontal, paddingGorizontal)
    }

    private func menuContent() -> some View {
        Group {
            Button(action: {
                voiceRecording.start()
            }, label: {
                Label(L10n.Alerts.recordAudioMessage, systemImage: "mic")
            })
            Button(action: {
                model.recordVideo()
            }, label: {
                Label(MessagePanelState.recordVido.toString(), systemImage: MessagePanelState.recordVido.imageName())
            })
            Button(action: {
                model.shareLocation()
            }, label: {
                Label(MessagePanelState.shareLocation.toString(), systemImage: MessagePanelState.shareLocation.imageName())
            })
            Button(action: {
                model.sendFile()
            }, label: {
                Label(MessagePanelState.sendFile.toString(), systemImage: MessagePanelState.sendFile.imageName())
            })
            Button(action: {
                model.openGalery()
            }, label: {
                Label(MessagePanelState.openGalery.toString(), systemImage: MessagePanelState.openGalery.imageName())
            })
            Button(action: {
                self.model.sendPhoto()
            }, label: {
                Label(MessagePanelState.sendPhoto.toString(), systemImage: MessagePanelState.sendPhoto.imageName())
            })
            .accessibilityHint(L10n.Accessibility.conversationCameraHint)

            if model.canWriteDocuments {
                Button(action: {
                    model.newCollabDocument()
                }, label: {
                    Label(MessagePanelState.newCollabDocument.toString(),
                          systemImage: MessagePanelState.newCollabDocument.imageName())
                })
            }
        }
    }
}

private struct MessagePanelGlass<S: Shape>: ViewModifier {
    let shape: S

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(in: shape)
        } else {
            content
                .background(VisualEffect(style: .systemUltraThinMaterial, withVibrancy: false))
                .clipShape(shape)
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 1)
        }
    }
}

extension View {
    func messagePanelGlass<S: Shape>(in shape: S) -> some View {
        modifier(MessagePanelGlass(shape: shape))
    }

    func messagePanelControlBackground(size: CGFloat) -> some View {
        frame(width: size, height: size)
            .messagePanelGlass(in: Circle())
    }
}
