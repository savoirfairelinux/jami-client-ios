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

struct Flipped: ViewModifier {
    func body(content: Content) -> some View {
        content
            .rotationEffect(.radians(Double.pi))
            .scaleEffect(x: -1, y: 1, anchor: .center)
    }
}

extension View {
    func flipped() -> some View {
        modifier(Flipped())
    }
}

struct MessagesListView: View {
    @StateObject var list: MessagesListVM
    var body: some View {
        ScrollViewReader { scrollView in
            ScrollView(showsIndicators: false) {
                LazyVStack {
                    ForEach(list.messagesModels) { message in
                        MessageRowView(messageModel: message, model: message.messageRow)
                            .onAppear { self.list.messagesAddedToScreen(messageId: message.id) }
                            .onDisappear { self.list.messagesremovedFromScreen(messageId: message.id) }
                    }
                    .flipped()
                    Text("")
                        .onAppear(perform: {
                            DispatchQueue.global(qos: .background)
                                .asyncAfter(deadline: DispatchTime(uptimeNanoseconds: 10)) {
                                    self.list.loadMore()
                                }
                        })
                }
                .listRowBackground(Color.clear)
                .onReceive(list.$scrollToId, perform: { (scrollToId) in
                    guard scrollToId != nil else { return }
                    scrollView.scrollTo(scrollToId)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        list.scrollToId = nil
                    }
                })
            }
        }
        .flipped()
    }
}
