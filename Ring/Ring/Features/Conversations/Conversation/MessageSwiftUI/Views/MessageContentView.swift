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
    @StateObject var reactionsModel: ReactionsContainerModel
    var onLongPress: (_ frame: CGRect, _ message: MessageBubbleView) -> Void
    let padding: CGFloat = 12
    @SwiftUI.State private var reactionsTextSize: CGSize = .zero
    var showReactionsView: (_ message: ReactionsContainerModel?) -> Void

    var body: some View {
        ZStack(alignment: Alignment.bottomTrailing) {
            VStack(alignment: messageModel.replyTarget.alignment) {
                if messageModel.messageContent.isHistory {
                    renderReplyHistory()
                }
                MessageBubbleView(messageModel: messageModel, model: model, onLongPress: onLongPress)
                    .onAppear {
                        self.model.onAppear()
                    }
                    .offset(y: messageModel.messageContent.isHistory ? -padding : 0)
            }
            .padding(.bottom, !messageModel.hasReactions() ? 2 : reactionsTextSize.height - 10)
            if messageModel.hasReactions() {
                renderReactions()
            }
        }
        .onPreferenceChange(SizePreferenceKey.self) { preferences in
            self.reactionsTextSize = preferences
        }
        .offset(y: messageModel.messageContent.isHistory ? padding : 0)
        .padding(.vertical, 2)
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

    private func renderReactions() -> some View {
        Text(reactionsModel.reactionsString)
            .font(.callout)
            .bold()
            .lineLimit(nil)
            .lineSpacing(5)
            .padding(5)
            .background(Color.white)
            .cornerRadius(10)
            .padding(.trailing, 10)
            .padding(.leading, 30)
            .shadowForConversation()
            .measureSize()
            .onLongPressGesture(minimumDuration: 0.5) {
                self.showReactionsView(reactionsModel)
            }
            .onAppear {
                self.messageModel.reactionsModel.onAppear()
            }
    }
}
