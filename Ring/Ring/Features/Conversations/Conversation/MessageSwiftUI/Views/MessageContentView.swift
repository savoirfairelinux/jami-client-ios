/*
 *  Copyright (C) 2022 Savoir-faire Linux Inc.
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

struct SizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

class CustomLinkView: LPLinkView {
    override var intrinsicContentSize: CGSize { CGSize(width: 0, height: super.intrinsicContentSize.height) }
}

struct URLPreview: UIViewRepresentable {
    typealias UIViewType = CustomLinkView

    var metadata: LPLinkMetadata
    var maxDimension: CGFloat

    func makeUIView(context: Context) -> CustomLinkView {
        let view = CustomLinkView(metadata: metadata)
        view.frame = CGRect(x: 0, y: 0, width: maxDimension, height: maxDimension)
        view.contentMode = .scaleAspectFit
        return view
    }

    func updateUIView(_ uiView: CustomLinkView, context: Context) {}
}

class ScaledImageView: UIImageView {
    var maxHeight: CGFloat = 300
    var maxWidth: CGFloat = 250
    override var intrinsicContentSize: CGSize {
        if let imageSize = self.image?.size {
            if imageSize.width < maxWidth && imageSize.height < maxHeight {
                return imageSize
            }
            let widthRatio = maxWidth / imageSize.width
            let heightRatio = maxHeight / imageSize.height
            let ratio = min(widthRatio, heightRatio)
            return CGSize(width: imageSize.width * ratio, height: imageSize.height * ratio)
        }
        return CGSize(width: -1, height: -1)
    }
}

struct ScaledImageViewWrapper: UIViewRepresentable {
    let imageToShow: UIImage

    func makeUIView(context: Context) -> ScaledImageView {
        let imageView = ScaledImageView()
        imageView.image = imageToShow
        return imageView
    }
    func updateUIView(_ uiView: UIViewType, context: Context) {}
}

struct MessageTextStyle: ViewModifier {
    @StateObject var model: MessageContentVM

    func body(content: Content) -> some View {
        content
            .padding(.top, model.textVerticalInset)
            .padding(.bottom, model.textVerticalInset)
            .padding(.leading, model.textInset)
            .padding(.trailing, model.textInset)
            .foregroundColor(model.textColor)
            .background(model.backgroundColor)
            .font(model.textFont)
            .if(model.hasBorder) { view in
                view.overlay(
                    CornerRadiusShape(radius: model.cornerRadius, corners: model.corners)
                        .stroke(model.borderColor, lineWidth: 2))
            }
            .modifier(MessageCornerRadius(model: model))
    }
}

struct MessageLongPress: ViewModifier {
    var longPressCb: (() -> Void)

    func body(content: Content) -> some View {
        content
            .onLongPressGesture(minimumDuration: 0.2, perform: longPressCb)
    }
}

struct MessageCornerRadius: ViewModifier {
    @StateObject var model: MessageContentVM

    func body(content: Content) -> some View {
        content
            .if(!model.hasBorder) { view in
                view.cornerRadius(radius: model.cornerRadius, corners: model.corners)
            }
            .cornerRadius(3)
    }
}

struct MessageContentView: View {
    let messageModel: MessageContainerModel
    @StateObject var model: MessageContentVM
    @SwiftUI.State private var frame: CGRect = .zero
    @SwiftUI.State private var presentMenu = false
    @Environment(\.openURL) var openURL
    @Environment(\.colorScheme) var colorScheme
    var onLongPress: (_ frame: CGRect, _ message: MessageContentView) -> Void
    let padding: CGFloat = 12
    @SwiftUI.State private var textSize: CGSize = .zero
    @Binding var showExplanation: Bool
    @SwiftUI.State private var textPosition: CGRect = .zero
    @SwiftUI.State private var reactionAlignment = Alignment.bottomTrailing
    @SwiftUI.State private var contentwidth: CGFloat = .zero
    @SwiftUI.State private var explanationwidth: CGFloat = .zero

    var body: some View {
        ZStack(alignment: reactionAlignment) {
            VStack(alignment: messageModel.replyTarget.alignment) {
                if messageModel.messageContent.isHistory {
                    renderReplyHistory()
                }
                VStack {
                    if model.type == .call {
                        renderCallMessage()
                    } else if model.type == .fileTransfer {
                        renderMediaContent()
                    } else if model.type == .text {
                        renderTextContent()
                    }
                }
                .background(
                    GeometryReader { proxy in
                        Rectangle().fill(Color.clear)
                            .onAppear {
                                self.contentwidth = proxy.frame(in: .global).width
                            }
                            .onChange(of: presentMenu, perform: { _ in
                                if !presentMenu {
                                    return
                                }
                                DispatchQueue.main.async {
                                    let frame = proxy.frame(in: .global)
                                    presentMenu = false
                                    onLongPress(frame, self)
                                }
                            })
                    }
                )
                .onAppear {
                    self.model.onAppear()
                }
                .offset(y: messageModel.messageContent.isHistory ? -padding : 0)
            }
            .padding(.bottom, model.getReactionsString() == nil ? 2 : textSize.height - 10)
            if let reactions = model.getReactionsString() {
                Text(reactions)
                    .lineLimit(nil)
                    .lineSpacing(5)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 5)
                    .background(Color.white)
                    .cornerRadius(10)
                    .padding(.trailing, 10)
                    .padding(.leading, 30)
                    .shadow(radius: 0.2, x: 0.5, y: 0.5)
                    .background(GeometryReader { geometry in
                        Color.clear
                            .preference(key: SizePreferenceKey.self, value: geometry.size)
                            .onAppear {
                                self.textPosition = geometry.frame(in: .global)
                            }
                    })
                    .onLongPressGesture(minimumDuration: 0.5) {
                        self.showExplanation.toggle()

                    }
                    .simultaneousGesture(
                        TapGesture()
                            .onEnded { _ in
                                self.showExplanation = false
                            }
                    )
                if showExplanation {
                    explanationView()
                        .background(GeometryReader { geometry in
                            Color.clear
                                .onAppear {
                                    self.explanationwidth = geometry.frame(in: .global).width
                                }
                        })
                }
            }
        }
        .onPreferenceChange(SizePreferenceKey.self) { preferences in
            self.textSize = preferences
        }
        .offset(y: messageModel.messageContent.isHistory ? padding : 0)
        .padding(.vertical, 2)
        .onChange(of: showExplanation) { _ in
            let align = contentwidth < explanationwidth || contentwidth < 100
            reactionAlignment = showExplanation ? align ? Alignment.bottomLeading : Alignment.bottomTrailing : Alignment.bottomTrailing
        }
    }

    private func explanationView() -> some View {
        Text("Explanation text here")
            .padding()
            .background(Color.blue)
            .cornerRadius(10)
            .foregroundColor(.white)
    }

    private func renderEmojiContainer(emojis: [MessageReaction]) -> some View {
        HStack {
            ForEach(emojis) { reaction in
                Text(reaction.content)
            }
        }
    }

    private func renderReplyHistory() -> some View {
        HStack {
            if messageModel.replyTarget.alignment == .leading {
                Spacer().frame(width: padding)
            }
            ReplyHistory(model: messageModel.replyTarget)
            if messageModel.replyTarget.alignment == .trailing {
                Spacer().frame(width: padding)
            }
        }
    }

    private func renderCallMessage()  -> some View {
        Text(model.content)
            .padding(model.textInset)
            .foregroundColor(model.textColor)
            .lineLimit(1)
            .background(model.backgroundColor)
            .font(model.textFont)
            .modifier(MessageCornerRadius(model: model))
    }

    private func renderImage(image: UIImage) -> some View {
        Group {
            if !model.isGifImage() {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(minHeight: 50, maxHeight: 300)
                    .onTapGesture {}
                    .modifier(MessageCornerRadius(model: model))
                    .modifier(MessageLongPress(longPressCb: receivedLongPress()))
            } else {
                ScaledImageViewWrapper(imageToShow: image)
                    .scaledToFit()
                    .frame(maxHeight: 300)
                    .onTapGesture {}
                    .modifier(MessageCornerRadius(model: model))
                    .modifier(MessageLongPress(longPressCb: receivedLongPress()))
            }
        }
    }

    private func renderTextContent() -> some View {
        Group {
            if let metadata = model.metadata {
                URLPreview(metadata: metadata, maxDimension: model.maxDimension)
                    .modifier(MessageCornerRadius(model: model))
            } else if model.content.isValidURL, let url = model.getURL() {
                Text(model.content)
                    .applyTextStyle(model: model)
                    .onTapGesture {
                        openURL(url)
                    }
                    .modifier(MessageLongPress(longPressCb: receivedLongPress()))
            } else {
                Text(model.content)
                    .applyTextStyle(model: model)
                    .lineLimit(nil)
                    .onTapGesture {}
                    .modifier(MessageLongPress(longPressCb: receivedLongPress()))
            }
        }
    }

    private func renderMediaContent() -> some View {
        Group {
            if let player = self.model.player {
                ZStack(alignment: .center) {
                    if colorScheme == .dark {
                        model.borderColor
                            .modifier(MessageCornerRadius(model: model))
                            .frame(width: model.playerWidth + 2, height: model.playerHeight + 2)
                    }
                    PlayerSwiftUI(model: model, player: player, onLongGesture: receivedLongPress())
                        .modifier(MessageCornerRadius(model: model))
                }
            } else if let image = model.finalImage {
                renderImage(image: image)
            } else {
                DefaultTransferView(model: model, onLongGesture: receivedLongPress())
                    .modifier(MessageCornerRadius(model: model))
            }
        }
    }

    private func receivedLongPress() -> (() -> Void) {
        return {
            if model.menuItems.isEmpty { return }
            presentMenu = true
        }
    }

    private var contentWidth: CGFloat {
        let padding: CGFloat = 20
        return UIScreen.main.bounds.size.width - padding * 2
    }
}
