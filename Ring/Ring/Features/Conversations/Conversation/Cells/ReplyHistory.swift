//
//  ReplyHistory.swift
//  Ring
//
//  Created by kateryna on 2022-09-27.
//  Copyright © 2022 Savoir-faire Linux. All rights reserved.
//

import SwiftUI

struct ReplyHistory: View {
    let messageModel: MessageViewModel
    var model: MessageHistoryModel {
        return messageModel.historyModel
    }
    var body: some View {
        VStack {
            HStack(alignment: .bottom) {
                //                if let aimage = test.avatarImage {
                //                    Image(uiImage: aimage)
                //                        .resizable()
                //                        .scaledToFit()
                //                        .frame(width: 30, height: 30)
                //                        .background(Color.blue)
                //                        .cornerRadius(15)
                //                }
                //                VStack {
                //                    Text(test.username)
                //                        .font(.callout)
                //                        .foregroundColor(.secondary)
                //                        .frame(maxWidth: .infinity, alignment: .leading)
                //                    Spacer()
                //                        .frame(height: 5)
                //                    HStack(alignment: .bottom) {
                //                        if let image = test.image {
                //                            Image(uiImage: image)
                //                                .resizable()
                //                                .scaledToFit()
                //                                .frame(width: 100, height: 100)
                //                                .background(Color.blue)
                //                                .cornerRadius(20)
                //                        } else {
                //                            Text(test.content)
                //                                .frame(maxWidth: .infinity, alignment: .center)
                //                                .padding(EdgeInsets(top: 15, leading: 0, bottom: 15, trailing: 0))
                //                                .foregroundColor(.secondary)
                //                                .font(.body)
                //                                .overlay(
                //                                    CornerRadiusShape(radius: 15, corners: [.topLeft, .topRight, .bottomRight])
                //                                        .stroke(.gray, lineWidth: 2)
                //                                )
                //                        }
                //                    }
                //                }
            }
            .padding(EdgeInsets(top: 15, leading: 15, bottom: 5, trailing: 15))

            Button("2 Replies") {
                print("Button tapped!")
            }
            .padding(EdgeInsets(top: 0, leading: 0, bottom: 15, trailing: 0))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(.green, lineWidth: 2)
        )
        .padding()
    }
}

struct ReplyHistory_Previews: PreviewProvider {
    static var previews: some View {
        ReplyHistory(messageModel: MessageViewModel())
    }
}
