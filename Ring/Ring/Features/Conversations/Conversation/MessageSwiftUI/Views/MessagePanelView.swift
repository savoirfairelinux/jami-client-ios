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

struct MessageTopBaseView<Content>: View where Content: View {
    var model: MessagePanelVM
    let padding: CGFloat = 10
    let content: Content
    let closeAction: () -> Void

    init(model: MessagePanelVM, closeAction: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.closeAction = closeAction
        self.content = content()
        self.model = model
    }

    var body: some View {
        Rectangle()
            .frame(height: 1)
            .foregroundColor(model.styling.secondaryTextColor)
            .padding(.horizontal, padding * 0.5)
        HStack(alignment: .center) {
            Spacer().frame(width: padding)
            content
            Spacer()
            Button(action: closeAction, label: {
                Image(systemName: "xmark.circle")
                    .resizable()
                    .font(Font.title.weight(.light))
                    .imageScale(.small)
                    .scaledToFit()
                    .padding(9)
                    .frame(width: 40, height: 40)
                    .foregroundColor(model.styling.secondaryTextColor)
            })
        }
        .padding(.vertical, padding)
        .padding(.horizontal, 0)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(10)
    }
}

struct ReplyViewInMessagePanel: View {
    var messageToReply: MessageContentVM
    @StateObject var model: MessagePanelVM
    let padding: CGFloat = 10

    var body: some View {
        MessageTopBaseView(model: model, closeAction: model.cancelReply) {
            VStack(alignment: .leading, spacing: 6) {
                (Text(L10n.Conversation.inReplyTo) +
                    Text(" \(model.inReplyTo)").bold())
                    .font(model.styling.secondaryFont)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundColor(model.styling.textColor)
                Text(messageToReply.message.content)
                    .font(model.styling.secondaryFont)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundColor(model.styling.secondaryTextColor)
            }
            Spacer()
                .frame(width: padding)
            if messageToReply.type == .fileTransfer {
                if let player = messageToReply.player, player.hasVideo.value {
                    PlayerSwiftUI(model: messageToReply, player: player, onLongGesture: {}, ratio: 0.4, withControls: false, customCornerRadius: 10)
                } else if let image = messageToReply.finalImage {
                    ImageOrGifView(message: messageToReply, image: image, onLongGesture: {}, minHeight: 20, maxHeight: 50, customCornerRadius: 10)
                }
            } else if messageToReply.type == .text,
                      let metadata = messageToReply.metadata {
                URLPreview(metadata: metadata, maxDimension: 50)
                    .cornerRadius(messageToReply.cornerRadius)
            }
        }
    }
}

struct EditMessagePanel: View {
    var messageToEdit: MessageContentVM
    @StateObject var model: MessagePanelVM
    @Binding var text: String
    let padding: CGFloat = 10

    var body: some View {
        MessageTopBaseView(model: model, closeAction: {
            model.cancelEdit()
            text = ""
        }) {
            Text(L10n.Global.editing)
                .font(model.styling.secondaryFont)
                .foregroundColor(Color(UIColor.systemBlue))
            Spacer()
                .frame(width: 5)
            Text(messageToEdit.message.content)
                .font(model.styling.secondaryFont)
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundColor(model.styling.secondaryTextColor)
        }
    }
}

struct MessagePanelView: View {
    @StateObject var model: MessagePanelVM
    @Binding var isFocused: Bool
    @SwiftUI.State private var text: String = ""
    @SwiftUI.State private var textHeight: CGFloat = 0
    let padding: CGFloat = 10
    let defaultControlSize: CGFloat = 42

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

    var body: some View {
        VStack {
            if let message = model.messageToReply {
                ReplyViewInMessagePanel(messageToReply: message, model: model)
            } else if let editMesage = model.messageToEdit {
                EditMessagePanel(messageToEdit: editMesage, model: model, text: $text)
                    .onAppear {
                        text = editMesage.content
                    }
            }
            HStack(alignment: .bottom, spacing: 1) {
                Menu(content: menuContent, label: {
                    MessagePanelImageButton(model: model, systemName: "plus.circle", width: defaultControlSize, height: defaultControlSize)
                })
                .accessibilityLabel(L10n.Accessibility.conversationShareMedia)
                .accessibilityRemoveTraits(.isButton)

                Button(action: {
                    self.model.sendPhoto()
                }, label: {
                    MessagePanelImageButton(model: model, systemName: "camera", width: 44, height: defaultControlSize)
                })
                .accessibilityHint(L10n.Accessibility.conversationCameraHint)

                Spacer()
                    .frame(width: 5)
                UITextViewWrapper(withBackground: true, text: $text, isFocused: $isFocused, dynamicHeight: $textHeight)
                    .frame(minHeight: textHeight, maxHeight: textHeight)
                    .cornerRadius(18)
                    .accessibilityLabel(L10n.Accessibility.conversationComposeMessage)
                    .placeholder(when: text.isEmpty, alignment: .leading) {
                        Text(model.placeholder)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .font(model.styling.textFont)
                            .foregroundColor(model.styling.secondaryTextColor)
                            .cornerRadius(18)
                            .accessibilityHidden(/*@START_MENU_TOKEN@*/true/*@END_MENU_TOKEN@*/)
                    }
                Spacer()
                    .frame(width: 10)
                Button(action: {
                    self.model.sendMessage(text: text)
                    cleanState()
                }, label: {
                    if text.isEmpty {
                        Text(model.defaultEmoji)
                            .font(.system(size: 27))
                            .frame(width: defaultControlSize, height: 40)
                            .padding(.bottom, 2)
                    } else {
                        MessagePanelImageButton(model: model, systemName: "paperplane", width: defaultControlSize, height: defaultControlSize)
                    }
                })
                .animation(.default, value: text.isEmpty)
            }
        }
        .padding(padding)
        .background(
            VisualEffect(style: .regular, withVibrancy: false)
                .ignoresSafeArea(edges: [.leading, .trailing, .bottom])
        )
        .onChange(of: model.isEdit) { _ in
            isFocused = model.isEdit
        }
    }

    private func menuContent() -> some View {
        Group {
            Button(action: {
                model.recordAudio()
            }) {
                Label(MessagePanelState.recordAudio.toString(), systemImage: MessagePanelState.recordAudio.imageName())
            }
            Button(action: {
                model.recordVideo()
            }) {
                Label(MessagePanelState.recordVido.toString(), systemImage: MessagePanelState.recordVido.imageName())
            }
            Button(action: {
                model.shareLocation()
            }) {
                Label(MessagePanelState.shareLocation.toString(), systemImage: MessagePanelState.shareLocation.imageName())
            }
            Button(action: {
                model.sendFile()
            }) {
                Label(MessagePanelState.sendFile.toString(), systemImage: MessagePanelState.sendFile.imageName())
            }
            Button(action: {
                model.openGalery()
            }) {
                Label(MessagePanelState.openGalery.toString(), systemImage: MessagePanelState.openGalery.imageName())
            }
        }
    }

    func cleanState() {
        text = ""
        model.cancelReply()
        model.cancelEdit()
    }
}
