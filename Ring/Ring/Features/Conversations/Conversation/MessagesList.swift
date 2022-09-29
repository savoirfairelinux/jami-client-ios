//
//  MessagesList.swift
//  Ring
//
//  Created by kateryna on 2022-09-26.
//  Copyright © 2022 Savoir-faire Linux. All rights reserved.
//

import SwiftUI

struct MessagesList: View {
    @ObservedObject var list: MessagesListModel
    var body: some View {
        ScrollViewReader { scrollView in
            ScrollView {
                LazyVStack {
                    ForEach(list.messagesModels) { message in
                        MessageRow(messageModel: message, model: message.messageSwiftUI)
                            .onAppear { self.list.messagesAddedToScreen(messageId: message.id) }
                            .onDisappear { self.list.messagesremovedFromScreen(messageId: message.id) }
                            .onTapGesture {
                                self.list.messageTaped(message: message)
                            }
                    }
                }
                .listRowBackground(Color.clear)
                .onChange(of: list.messagesCount, perform: { _ in
                    scrollView.scrollTo(list.lastMessageOnScreen)
                })
            }
        }
    }
}

struct MessagesList_Previews: PreviewProvider {
    static var previews: some View {
        MessagesList(list: MessagesListModel())
    }
}
