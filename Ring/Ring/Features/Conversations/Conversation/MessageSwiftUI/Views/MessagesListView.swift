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

struct ScrollViewOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat?

    static func reduce(value: inout CGFloat?, nextValue: () -> CGFloat?) {
        value = value ?? nextValue()
    }
}

struct MessagesListView: View {
    @StateObject var list: MessagesListVM
    @SwiftUI.State var showScrollToLatestButton = false
    let scrollReserved = UIScreen.main.bounds.height * 1.5
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollViewReader { scrollView in
                ScrollView(showsIndicators: false) {
                    GeometryReader { proxy in
                        let offset = proxy.frame(in: .named("scroll")).minY
                        Color.clear.preference(key: ScrollViewOffsetPreferenceKey.self, value: offset)
                    }
                    LazyVStack(spacing: 0) {
                        Text("")
                            .id("lastMessage")
                        ForEach(list.messagesModels) { message in
                            MessageRowView(messageModel: message, model: message.messageRow)
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
                        scrollView.scrollTo("lastMessage")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            list.scrollToId = nil
                        }
                    })
                }
                .onPreferenceChange(ScrollViewOffsetPreferenceKey.self) { value in
                    DispatchQueue.main.async {
                        let scrollOffset = value ?? 0
                        let atTheBottom = scrollOffset < scrollReserved
                        if atTheBottom != list.atTheBottom {
                            list.atTheBottom = atTheBottom
                        }
                    }
                }
            }
            .flipped()
            if !list.atTheBottom {
                Button(action: {
                    list.scrollToTheBottom()
                }) {
                    Image(systemName: "arrow.down")
                }
                .frame(width: 40, height: 40)
                .background(Color(UIColor.jamiMain))
                .foregroundColor(.white)
                .clipShape(Circle())
                .padding(.all, 15.0)
                .shadow(radius: 10)
            }
        }
    }
}
