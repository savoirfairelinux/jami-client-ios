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
                        MessageRow(messageModel: message, model: message.messageRow)
                            .onAppear { self.list.messagesAddedToScreen(messageId: message.id) }
                            .onDisappear {
                                self.list.messagesremovedFromScreen(messageId: message.id)
                            }
                            .onTapGesture {
                                self.list.messageTaped(message: message)
                            }
                    }
                    Spacer()
                        .frame(height: 40)
                        .id("lastMessageOnScreen")
                }
                .listRowBackground(Color.clear)
                .onChange(of: list.messagesCount, perform: { _ in
                    scrollView.scrollTo(list.lastMessageOnScreen)
                })
                .onChange(of: list.scrolToLast, perform: { updated in
                    if updated {
                        print("########will scroll")
                        scrollView.scrollTo("lastMessageOnScreen")
                        list.scrolToLast = false
                    }
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
