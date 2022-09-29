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
        HStack(alignment: .bottom) {
            if model.type == .fileTransfer {
                if let image = model.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .background(Color.blue)
                        .cornerRadius(20)
                } else {
                    HStack(alignment: .top) {
                        Image(systemName: "doc")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 40, height: 40)
                        VStack(alignment: .leading) {
                            Text(model.fileName)
                                .foregroundColor(model.textColor)
                                .background(model.backgroundColor)
                                .font(.headline)
                            Spacer()
                                .frame(height: 10)
                            Text(model.fileInfo)
                                .foregroundColor(model.textColor)
                                .background(model.backgroundColor)
                                .font(.callout)
                            ProgressView(value: model.fileProgress, total: 100)
                            HStack {
                                ForEach(model.transferActions) { action in
                                    Button(action.toString()) {
                                        model.transferAction(action: action)
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
                    // .frame(maxWidth: .infinity, alignment: .center)
                    .padding(model.textInset)
                    .foregroundColor(model.textColor)
                    .background(model.backgroundColor)
                    .font(.body)
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
