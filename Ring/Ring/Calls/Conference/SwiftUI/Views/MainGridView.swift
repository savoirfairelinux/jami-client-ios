/*
 *  Copyright (C) 2023 Savoir-faire Linux Inc.
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

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGPoint = .zero

    static func reduce(value _: inout CGPoint, nextValue _: () -> CGPoint) {}
}

struct MainGridView: View {
    @Binding var isAnimatingTopMainGrid: Bool
    @Binding var showMainGridView: Bool
    @ObservedObject var model: MainGridViewModel
    @Binding var participants: [ParticipantViewModel]
    @SwiftUI.State var selectedPage = 0
    @SwiftUI.State private var scrollPosition: CGPoint = .zero
    /*
     Redraw when participant order changes. This occurs when an active
     participant or a participant with an active voice is moved to the first page.
     */
    @SwiftUI.State private var shouldRedraw: UUID = .init()
    @SwiftUI.State private var scrollDisabled = true

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView(.horizontal, showsIndicators: true) {
                LazyHStack(alignment: .top, spacing: 0) {
                    ForEach(model.pages.indices, id: \.self) { index in
                        let page = model.pages[index]
                        PageSwiftUI(pageNumber: index + 1,
                                    participants: participants,
                                    page: page, isAnimatingTopMainGrid: $isAnimatingTopMainGrid,
                                    showMainGridView: $showMainGridView)
                            .clipped()
                    }
                }
                .background(Color.black.frame(width: 99_999_999))
                .background(GeometryReader { geometry in
                    Color.clear
                        .preference(
                            key: ScrollOffsetPreferenceKey.self,
                            value: geometry.frame(in: .named("scroll")).origin
                        )
                })
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                    self.scrollPosition = value
                    let newValue = abs(Int(self.scrollPosition.x / UIScreen.main.bounds.width))
                    if selectedPage != newValue {
                        withAnimation {
                            selectedPage = newValue
                        }
                    }
                }
                .onChange(of: selectedPage) { _ in
                    scrollProxy.scrollTo(selectedPage)
                }
            }
            .onChange(of: model.firstParticipant) { _ in
                shouldRedraw = UUID()
            }
            .onChange(of: model.pages) { _ in
                scrollDisabled = model.pages.count < 2
                shouldRedraw = UUID()
            }
            .disabled(scrollDisabled)
            .ignoresSafeArea()
            .coordinateSpace(name: "scroll")
            .id(shouldRedraw)
        }
    }
}

struct PageSwiftUI: View {
    var pageNumber: Int
    var participants: [ParticipantViewModel]
    var page: Page
    @Binding var isAnimatingTopMainGrid: Bool
    @Binding var showMainGridView: Bool

    var body: some View {
        VStack(alignment: .center) {
            if page.rows > 0 {
                ForEach(1 ... page.rows, id: \.self) { row in
                    ParticipantRowView(row: row,
                                       columns: page.columns,
                                       participants: participants,
                                       isAnimatingTopMainGrid: $isAnimatingTopMainGrid,
                                       showMainGridView: $showMainGridView,
                                       page: page,
                                       pageNumber: pageNumber)
                }
            }
        }
    }
}

struct ParticipantRowView: View {
    var row: Int
    var columns: Int
    var participants: [ParticipantViewModel]
    @Binding var isAnimatingTopMainGrid: Bool
    @Binding var showMainGridView: Bool
    var page: Page
    var pageNumber: Int

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0 ..< columns, id: \.self) { column in
                let index = getIndex(column: column, row: row)
                if index < participants.count {
                    let participant = participants[index]
                    ExpandableParticipantView(model: participant,
                                              isAnimatingTopMainGrid: $isAnimatingTopMainGrid,
                                              showMainGridView: $showMainGridView,
                                              viewWidth: page.width,
                                              viewHeight: page.height)
                }
            }
        }
    }

    func getIndex(column: Int, row: Int) -> Int {
        let someRows: Int = (row - 1) * columns
        let something: Int = (pageNumber - 1) * columns * page.rows
        return column + someRows + something
    }
}
