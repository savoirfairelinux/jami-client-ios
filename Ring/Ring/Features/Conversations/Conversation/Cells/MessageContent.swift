//
//  MessageContent.swift
//  Ring
//
//  Created by kateryna on 2022-09-27.
//  Copyright © 2022 Savoir-faire Linux. All rights reserved.
//

import SwiftUI

struct MessageContent: View {
    @ObservedObject var model: MessageContentModel
    var body: some View {
        VStack(alignment: .leading) {
            if model.type == .fileTransfer {
                if let image = model.image {
                    if image.size.height > 300 {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 300)
                            .cornerRadius(20)
                    } else {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .cornerRadius(20)
                    }
                } else {
                    HStack(alignment: .top) {
                        Image(systemName: "doc")
                            .resizable()
                            .foregroundColor(model.textColor)
                            .scaledToFit()
                            .frame(width: 50, height: 50)
                        Spacer()
                            .frame(width: 10)
                        VStack(alignment: .leading) {
                            Text(model.fileName)
                                .foregroundColor(model.textColor)
                                .background(model.backgroundColor)
                                .font(.headline)
                            Spacer()
                                .frame(height: 5)
                            Text(model.fileInfo)
                                .foregroundColor(model.textColor)
                                .background(model.backgroundColor)
                                .font(.callout)
                            Spacer()
                                .frame(height: 15)
                            if model.showProgress {
                                ProgressView(value: model.fileProgress, total: 100)
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
        }
    }
}

struct MessageContent_Previews: PreviewProvider {
    static var previews: some View {
        MessageContent(model: MessageContentModel())
    }
}
