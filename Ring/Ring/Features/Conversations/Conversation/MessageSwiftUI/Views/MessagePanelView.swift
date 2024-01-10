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

struct UITextViewWrapper: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    @Binding var dynamicHeight: CGFloat
    let maxHeight: CGFloat = 100

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isScrollEnabled = true
        textView.textAlignment = .left
        textView.font = UIFont.systemFont(ofSize: UIFont.preferredFont(forTextStyle: .footnote).pointSize)
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        textView.backgroundColor = UIColor.secondarySystemBackground
        textView.layer.cornerRadius = 18
        textView.clipsToBounds = true
        textView.delegate = context.coordinator
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.text = text

        DispatchQueue.main.async {
            if self.isFocused && !uiView.isFirstResponder {
                uiView.becomeFirstResponder()
            }
            dynamicHeight = min(uiView.sizeThatFits(CGSize(width: uiView.frame.size.width, height: .infinity)).height, maxHeight)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: UITextViewWrapper

        init(_ textViewWrapper: UITextViewWrapper) {
            self.parent = textViewWrapper
        }

        func textViewDidChange(_ textView: UITextView) {
            self.parent.text = textView.text
        }
    }
}

struct MessagePanelView: View {
    @StateObject var model: MessagePanelVM
    @SwiftUI.State private var text: String = ""
    @SwiftUI.State private var isFocused: Bool = false
    @SwiftUI.State private var textHeight: CGFloat = 0

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
                        .font(.footnote)
                        .foregroundColor(Color(UIColor.secondaryLabel))
                        .cornerRadius(18)
                }
        }
    }

    var body: some View {
        VStack {
            if let message = model.messageToReply {
                HStack {
                    Spacer()
                    VStack(alignment: .leading) {
                        Text("Reply to " + message.stackViewModel.username)
                            .font(.caption)
                            .foregroundColor(Color(UIColor.secondaryLabel))
                        Text(message.message.content)
                            .font(.caption)
                            .foregroundColor(Color(UIColor.tertiaryLabel))
                    }
                    Spacer()
                    Button(action: {
                        model.cancelReply()
                    }, label: {
                        MessagePanelImageButton(systemName: "circle.grid.cross.fill", width: 40, height: 40)
                    })
                }.background(Color(UIColor.systemBackground))
            }
            HStack(alignment: .bottom, spacing: 1) {
                Button(action: {
                    self.model.showMoreActions()
                }, label: {
                    MessagePanelImageButton(systemName: "plus.circle", width: 40, height: 40)
                })
                Button(action: {
                    self.model.sendPhoto()
                }, label: {
                    MessagePanelImageButton(systemName: "camera", width: 42, height: 40)
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
                        MessagePanelImageButton(systemName: "paperplane", width: 40, height: 40)
                    }
                })
                .animation(.default, value: text.isEmpty)
            }
        }
        .padding(10)
        .background(
            VisualEffect(style: .regular, withVibrancy: false)
                .ignoresSafeArea(edges: [.leading, .trailing, .bottom])
        )
        .onChange(of: model.isReply) { _ in
            isFocused = model.isReply
        }
    }

    func cleanState() {
        text = ""
        model.cancelReply()
    }
}
