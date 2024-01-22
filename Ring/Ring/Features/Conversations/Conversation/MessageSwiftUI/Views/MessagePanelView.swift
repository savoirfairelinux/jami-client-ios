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
    let padding: CGFloat = 10
    let content: Content
    let closeAction: () -> Void

    init(closeAction: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.closeAction = closeAction
        self.content = content()
    }

    var body: some View {
        Rectangle()
            .frame(height: 1)
            .foregroundColor(Color(UIColor.secondaryLabel))
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
                    .foregroundColor(Color(UIColor.secondaryLabel))
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
        MessageTopBaseView(closeAction: model.cancelReply) {
            VStack(alignment: .leading, spacing: 6) {
                (Text(L10n.Conversation.inReplyTo) +
                    Text(" \(model.inReplyTo)").bold())
                    .font(.footnote)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundColor(Color(UIColor.label))
                Text(messageToReply.message.content)
                    .font(.footnote)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundColor(Color(UIColor.secondaryLabel))
            }
            Spacer()
                .frame(width: padding)
            if messageToReply.type == .fileTransfer {
                if let player = messageToReply.player, player.hasVideo.value {
                    PlayerSwiftUI(model: messageToReply, player: player, onLongGesture: {}, ratio: 0.4, withControls: false, customCornerRadius: 10)
                } else if let image = messageToReply.finalImage {
                    ImageOrGifView(message: messageToReply, image: image, onLongGesture: {}, minHeight: 20, maxHeight: 50)
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
        MessageTopBaseView(closeAction: {
            model.cancelEdit()
            text = ""
        }) {
            Text(L10n.Global.editing)
                .font(.footnote)
                .foregroundColor(Color(UIColor.systemBlue))
            Spacer()
                .frame(width: 5)
            Text(messageToEdit.message.content)
                .font(.footnote)
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundColor(Color(UIColor.secondaryLabel))
        }
    }
}

struct MessagePanelView: View {
    @StateObject var model: MessagePanelVM
    @SwiftUI.State private var text: String = ""
    @SwiftUI.State private var isFocused: Bool = false
    @SwiftUI.State private var textHeight: CGFloat = 0
    let padding: CGFloat = 10

    private struct MessagePanelImageButton: View {
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
                .foregroundColor(Color(UIColor.secondaryLabel))
        }
    }

    private struct CommonTextEditorStyle: ViewModifier {
        @Binding var text: String
        @Binding var placeholder: String

        func body(content: Content) -> some View {
            content
                .cornerRadius(18)
                .placeholder(when: text.isEmpty, alignment: .leading) {
                    Text(placeholder)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .font(.callout)
                        .foregroundColor(Color(UIColor.secondaryLabel))
                        .cornerRadius(18)
                }
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
                Button(action: {
                    self.model.showMoreActions()
                }, label: {
                    MessagePanelImageButton(systemName: "plus.circle", width: 42, height: 42)
                })
                Button(action: {
                    self.model.sendPhoto()
                }, label: {
                    MessagePanelImageButton(systemName: "camera", width: 44, height: 42)
                })

                Spacer()
                    .frame(width: 5)
                UITextViewWrapper(text: $text, isFocused: $isFocused, dynamicHeight: $textHeight)
                    .frame(minHeight: textHeight, maxHeight: textHeight)
                    .modifier(CommonTextEditorStyle(text: $text, placeholder: $model.placeholder))
                Spacer()
                    .frame(width: 10)
                Button(action: {
                    self.model.sendMessage(text: text)
                    cleanState()
                }, label: {
                    if text.isEmpty {
                        Text(model.defaultEmoji)
                            .font(.title)
                            .frame(width: 36, height: 36)
                            .padding(.bottom, 2)
                    } else {
                        MessagePanelImageButton(systemName: "paperplane", width: 42, height: 42)
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

    func cleanState() {
        text = ""
        model.cancelReply()
        model.cancelEdit()
    }
}
