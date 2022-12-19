/*
 *  Copyright (C) 2022 Savoir-faire Linux Inc.
 *
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA.
 */

import SwiftUI

struct MessagesListView: View {
    @StateObject var list: MessagesListVM
    @SwiftUI.State var temporaryMessagesModels = [MessageContainerModel]()
    @SwiftUI.State var isHidingList = false
    @SwiftUI.State var couldLoad = false
    var body: some View {
        if isHidingList {
            listView
        } else {
            listView
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        couldLoad = true
                    }
                }
        }
    }

    private var listView: some View {
        ScrollViewReader { scrollView in
            ScrollView {
                LazyVStack {
                    if isHidingList {
                        ForEach(temporaryMessagesModels) { message in
                            MessageRowView(messageModel: message, model: message.messageRow)
                                .id(message.id)
                        }
                    } else {
                        Text("")
                            .onAppear {
                                if couldLoad {
                                    list.loadMore()
                                }
                            }
                        ForEach(list.messagesModels) { message in
                            withAnimation {
                                MessageRowView(messageModel: message, model: message.messageRow)
                                    .onAppear { self.list.messagesAddedToScreen(messageId: message.id) }
                                    .onDisappear { self.list.messagesremovedFromScreen(messageId: message.id) }
                                    .id(message.id)

                            }
                        }
                    }
                }
                .listRowBackground(Color.clear)
                .onReceive(list.$loading) { newValue in
                    if newValue == isHidingList {
                        return
                    }
                    if newValue {
                        self.temporaryMessagesModels = self.list.messagesModels
                        couldLoad = false
                    }
                    DispatchQueue.main.async {
                        isHidingList = newValue
                    }
                }
                .onAppear {
                    scrollView.scrollTo(list.lastMessageOnScreen)
                }
                                .onReceive(list.$needScroll, perform: { (updated) in
                                    if updated {
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                            scrollView.scrollTo(list.lastMessageOnScreen)
                                            list.needScroll = false
                                        }
                                    }
                                })
            }
        }
    }
}
