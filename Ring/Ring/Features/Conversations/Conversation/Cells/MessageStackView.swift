//
//  MessageStackView.swift
//  Ring
//
//  Created by kateryna on 2022-10-24.
//  Copyright © 2022 Savoir-faire Linux. All rights reserved.
//

import SwiftUI

struct MessageStackView: View {
    let model: TestMessageModel
    // @ObservedObject var test = TestMessageModel()
    var body: some View {
        let alignmentH: HorizontalAlignment = (model.messageModel?.message.incoming ?? true) ? HorizontalAlignment.leading : HorizontalAlignment.trailing
        VStack(alignment: alignmentH) {
            if let parent = model.replyTo {
                ReplyHistory(test: parent)
            }
            if model.messageModel?.message.incoming ?? true {
                Text(model.username)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 0))
                Spacer()
                    .frame(height: 10)
            }
            MessageContent(model: model.messageModel!.messageContent)
        }
    }
}

struct MessageStackView_Previews: PreviewProvider {
    static var previews: some View {
        MessageRow(model: TestMessageModel())
    }
}
