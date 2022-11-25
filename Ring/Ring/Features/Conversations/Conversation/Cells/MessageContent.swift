//
//  MessageContent.swift
//  Ring
//
//  Created by kateryna on 2022-09-27.
//  Copyright © 2022 Savoir-faire Linux. All rights reserved.
//

import SwiftUI

struct PlayerViewWrapper: UIViewRepresentable {
    var viewModel: PlayerViewModel
    var frame: CGRect
    func makeUIView(context: Context) -> PlayerView {
        let player = PlayerView(frame: frame)
        player.viewModel = viewModel
        return player
    }
    func updateUIView(_ uiView: PlayerView, context: Context) {

    }

    typealias UIViewType = PlayerView

}

struct MessageContent: View {
    let messageModel: MessageViewModel
    @StateObject var model: MessageContentModel
    var body: some View {
        VStack(alignment: .leading) {
            if model.type == .fileTransfer {
                if let player = model.player {
                    PlayerViewWrapper.init(viewModel: player, frame: CGRect(x: 0, y: 0, width: 300, height: 300))
                        .frame(minHeight: 200, maxHeight: 300)
                        .frame(minWidth: 200, maxWidth: 300)
                        .cornerRadius(20)

                } else if let image = model.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(minHeight: 50, maxHeight: 300)
                        .cornerRadius(20)
                } else {
                    HStack(alignment: .top) {
                        Spacer()
                            .frame(width: 1)
                        Image(systemName: "doc")
                            .resizable()
                            .foregroundColor(model.textColor)
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                        Spacer()
                            .frame(width: 10)
                        VStack(alignment: .leading) {
                            Text(model.fileName)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .foregroundColor(model.textColor)
                                .background(model.backgroundColor)
                                .font(.headline)
                            Spacer()
                                .frame(height: 10)
                            Text(model.fileInfo)
                                .foregroundColor(model.textColor)
                                .background(model.backgroundColor)
                                .font(.footnote)
                            if model.showProgress {
                                Spacer()
                                    .frame(height: 15)
                                ProgressView(value: model.fileProgress, total: 1)
                                Spacer()
                                    .frame(height: 10)
                            }
                            if !model.transferActions.isEmpty {
                                HStack {
                                    ForEach(model.transferActions) { action in
                                        Button(action.toString()) {
                                            model.transferAction(action: action)
                                        }
                                        Spacer()
                                            .frame(width: 20)
                                    }
                                }
                            }
                        }
                    }
                    .padding(model.textInset)
                    .background(model.backgroundColor)
                    .cornerRadius(radius: model.cornerRadius, corners: model.corners)
                }
            } else if model.type == .text {
                Text(model.content)
                    .padding(model.textInset)
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
        }.onAppear {
            self.model.onAppear()
        }
    }
}

struct MessageContent_Previews: PreviewProvider {
    static var previews: some View {
        MessageContent(messageModel: MessageViewModel(), model: MessageViewModel().messageContent)
    }
}
