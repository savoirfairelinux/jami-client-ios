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
    var body: some View {
        let alignmentH: HorizontalAlignment = model.incoming ? HorizontalAlignment.leading : HorizontalAlignment.trailing
        let alignment: Alignment = model.incoming ? Alignment.leading : Alignment.trailing
        VStack(alignment: alignmentH) {
            if messageModel.replyTo != nil {
                ReplyHistory(messageModel: messageModel)
            }
            if model.incoming && model.shouldDisplayName {
                Text(model.username)
                    .font(.footnote)
                    .foregroundColor(Color(UIColor.tertiaryLabel))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
                    .frame(height: 4)
            }
            MessageContent(messageModel: messageModel)
                .frame(maxWidth: .infinity, alignment: alignment)
        }
    }
}

struct MessageStackView_Previews: PreviewProvider {
    static var previews: some View {
        MessageRow(messageModel: MessageViewModel(), model: MessageSwiftUIModel())
    }
}
