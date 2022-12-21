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
    @StateObject var model: MessagesListVM
    @SwiftUI.State var showScrollToLatestButton = false
    let scrollReserved = UIScreen.main.bounds.height * 1.5
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollViewReader { scrollView in
                ScrollView(showsIndicators: false) {
                    // update scroll offset
                    GeometryReader { proxy in
                        let offset = proxy.frame(in: .named("scroll")).minY
                        Color.clear.preference(key: ScrollViewOffsetPreferenceKey.self, value: offset)
                    }
                    LazyVStack(spacing: 0) {
                        // scroll to the bottom
                        Text("")
                            .id("lastMessage")
                        // messages
                        ForEach(model.messagesModels) { message in
                            MessageRowView(messageModel: message, model: message.messageRow)
                        }
                        .flipped()
                        // load more
                        Text("")
                            .onAppear(perform: {
                                DispatchQueue.global(qos: .background)
                                    .asyncAfter(deadline: DispatchTime(uptimeNanoseconds: 10)) {
                                        self.model.loadMore()
                                    }
                            })
                    }
                    .listRowBackground(Color.clear)
                    .onReceive(model.$scrollToId, perform: { (scrollToId) in
                        guard scrollToId != nil else { return }
                        scrollView.scrollTo("lastMessage")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            model.scrollToId = nil
                        }
                    })
                }
                .onPreferenceChange(ScrollViewOffsetPreferenceKey.self) { value in
                    DispatchQueue.main.async {
                        let scrollOffset = value ?? 0
                        let atTheBottom = scrollOffset < scrollReserved
                        if atTheBottom != model.atTheBottom {
                            model.atTheBottom = atTheBottom
                        }
                    }
                }
            }
            .flipped()
            if !model.atTheBottom {
                createScrollToBottmView()
            }
        }
    }

    func createScrollToBottmView() -> some View {
        return VStack(alignment: .trailing, spacing: -10) {
            if model.numberOfNewMessages > 0 {
                Text("\(model.numberOfNewMessages)")
                    .font(.callout)
                    .padding(.trailing, 6.0)
                    .padding(.leading, 6.0)
                    .padding(.top, 1.0)
                    .padding(.bottom, 1.0)
                    .background(Color(UIColor.jamiButtonDark))
                    .foregroundColor(Color.white)
                    .cornerRadius(radius: 8, corners: .allCorners)
                    .zIndex(1)
            }
            Button(action: {
                model.scrollToTheBottom()
            }) {
                Image(systemName: "arrow.down")
                    .frame(width: 45, height: 45)
                    .overlay(
                        Circle()
                            .stroke(Color(UIColor.jamiButtonDark), lineWidth: 1)
                    )
                    .background(Color.white)
                    .clipShape(Circle())
                    .foregroundColor(Color(UIColor.jamiButtonDark))
                    .zIndex(0)
            }
        }
        .padding(.trailing, 15.0)
        .padding(.leading, 15.0)
        .padding(.top, 0.0)
        .padding(.bottom, 5.0)
    }
}
