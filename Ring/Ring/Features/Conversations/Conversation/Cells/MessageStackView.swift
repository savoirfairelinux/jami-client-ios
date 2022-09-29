//
//  MessageStackView.swift
//  Ring
//
//  Created by kateryna on 2022-10-24.
//  Copyright © 2022 Savoir-faire Linux. All rights reserved.
//

import SwiftUI

struct MessageStackView: View {
    let messageModel: MessageViewModel
    var model: MessageStackViewModel {
        return messageModel.stackViewModel
    }
    // @ObservedObject var test = TestMessageModel()
    var body: some View {
        let alignmentH: HorizontalAlignment = model.incoming ? HorizontalAlignment.leading : HorizontalAlignment.trailing
        VStack(alignment: alignmentH) {
            if messageModel.replyTo != nil {
                ReplyHistory(messageModel: messageModel)
            }
            if model.incoming && model.shouldDisplayName {
                Text(model.username)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
                    .frame(height: 10)
            }
            MessageContent(messageModel: messageModel)
        }
    }
}

struct MessageStackView_Previews: PreviewProvider {
    static var previews: some View {
        MessageRow(messageModel: MessageViewModel())
    }
}
