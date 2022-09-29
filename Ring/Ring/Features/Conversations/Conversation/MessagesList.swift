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
    @State var enabled = true
    var body: some View {
        ScrollViewReader { scrollView in
            // ScrollView(.vertical) {
            List {
                ForEach(list.messagesModels) { message in
                    // MessageRow()
                    MessageRow(model: TestMessageModel(messageModel: message))
                        .onAppear { self.list.messagesAddedToScreen(messageId: message.id) }
                        .onDisappear { self.list.messagesremovedFromScreen(messageId: message.id) }
                }
            }
            .listRowBackground(Color.clear)
            .disabled(enabled == false)
            //            .onChange(of: list.scrollEnabled, perform: {wwwwwww in
            //                print("*****scrolling enabled: \(list.scrollEnabled)")
            //                // UIScrollView.appearance().isScrollEnabled = enabled
            //                enabled = wwwwwww
            //            })
            // }
            .onChange(of: list.messagesCount, perform: { lastId in
                print("*****scrolling to \(list.lastId)")
                scrollView.scrollTo(list.lastId, anchor: .bottom)
            }).onChange(of: list.scrollEnabled, perform: {wwwwwww in
                print("*****scrolling enabled: \(list.scrollEnabled)")
                // UIScrollView.appearance().isScrollEnabled = enabled
                enabled = wwwwwww
            })
            //            .onAppear(perform: {
            //                UIScrollView.appearance().isScrollEnabled = false
            //            })
            //        }.onChange(of: list.scrollEnabled, perform: {wwwwwww in
            //            print("*****scrolling enabled: \(list.scrollEnabled)")
            //            // UIScrollView.appearance().isScrollEnabled = enabled
            //            enabled = wwwwwww
            //        })
            //        .onAppear(perform: {
            //            UIScrollView.appearance().isScrollEnabled = false
            //        })
        }
    }
}

struct MessagesList_Previews: PreviewProvider {
    static var previews: some View {
        MessagesList(list: MessagesListModel())
    }
}
