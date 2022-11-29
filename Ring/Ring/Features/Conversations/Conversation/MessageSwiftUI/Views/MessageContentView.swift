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
import LinkPresentation

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

struct MessageContentView: View {
    let messageModel: MessageContainerModel
    @StateObject var model: MessageContentVM
    var body: some View {
        VStack(alignment: .leading) {
            if model.type == .call {
                Text(model.content)
                    .padding(model.textInset)
                    .foregroundColor(model.textColor)
                    .lineLimit(1)
                    .background(model.backgroundColor)
                    .font(model.textFont)
                    .cornerRadius(radius: model.cornerRadius, corners: model.corners)
            } else if model.type == .fileTransfer {
                if let player = self.model.player {
                    PlayerSwiftUI(model: model, player: player)
                        .cornerRadius(radius: model.cornerRadius, corners: model.corners)
                } else if let image = self.model.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(minHeight: 50, maxHeight: 300)
                        .cornerRadius(radius: model.cornerRadius, corners: model.corners)
                } else {
                    DefaultTransferView(model: model)
                }
            } else if model.type == .text {
                if let metadata = model.metadata {
                    URLPreview(metadata: metadata, maxDimension: model.maxDimension)
                        .cornerRadius(radius: model.cornerRadius, corners: model.corners)
                } else if model.content.isValidURL, let url = URL(string: model.content) {
                    Link(model.content, destination: url)
                        .padding(model.textInset)
                        .cornerRadius(radius: model.cornerRadius, corners: model.corners)
                } else {
                    Text(model.content)
                        .padding(.top, model.textVerticalInset)
                        .padding(.bottom, model.textVerticalInset)
                        .padding(.leading, model.textInset)
                        .padding(.trailing, model.textInset)
                        .foregroundColor(model.textColor)
                        .lineLimit(nil)
                        .background(model.backgroundColor)
                        .font(model.textFont)
                        .if(model.hasBorder) { view in
                            view.overlay(
                                CornerRadiusShape(radius: model.cornerRadius, corners: model.corners)
                                    .stroke(model.borderColor, lineWidth: 2))
                        }
                        .if(!model.hasBorder) { view in
                            view.cornerRadius(radius: model.cornerRadius, corners: model.corners)
                        }
                }
            }
        }.contextMenu {
            ForEach(model.menuItems) { item in
                Button {
                    model.contextMenuSelect(item: item)
                } label: {
                    Label(item.toString(), systemImage: item.image())
                }
            }
        }
        .onAppear {
            self.model.onAppear()
        }
    }
}
