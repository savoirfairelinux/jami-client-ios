//
//  CollectionView.swift
//  Ring
//
//  Created by kateryna on 2023-06-01.
//  Copyright © 2023 Savoir-faire Linux. All rights reserved.
//

import SwiftUI

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGPoint = .zero

    static func reduce(value: inout CGPoint, nextValue: () -> CGPoint) {
    }
}

struct PageSwiftUI: View {
    var pageNumber: Int
    var participants: [ParticipantViewModel]
    var page: Page
    var body: some View {
        VStack(alignment: .center) {
            if page.rows > 0 {
                ForEach(1...page.rows, id: \.self) { row in
                    HStack(spacing: 10) {
                        ForEach(0...(page.columns - Int(1)), id: \.self) {column in
                            let number = getNumber(column: column, row: row)
                            if number < participants.count {
                                let participant = participants[number]
                                ParticipantView(model: participant)
                                    .frame(width: page.width, height: page.height)
                                    .clipped()
                            }

                        }
                    }
                }
            }
        }
    }

    func getNumber(column: Int, row: Int) -> Int {
        let somerows: Int = (row - 1) * page.columns
        let something: Int = (pageNumber - 1) * page.columns * page.rows
        return column + somerows + something
    }
}

struct CollectionView: View {
    @ObservedObject var model: CollectionViewModel
    @SwiftUI.State var selectedPage = 0
    @SwiftUI.State private var scrollPosition: CGPoint = .zero
    var transition: AnyTransition {
        .move(edge: .top).combined(with: .opacity)
    }
    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView(.horizontal, showsIndicators: true) {
                LazyHStack(alignment: .top, spacing: 0) {
                    ForEach(model.pages.indices, id: \.self) { index in
                        let page = model.pages[index]
                        PageSwiftUI(pageNumber: (index + 1), participants: model.participants, page: page)
                            .clipped()
                    }
                }
                .background(Color.black.frame(width: 99999999))
                .background(GeometryReader { geometry in
                    Color.clear
                        .preference(key: ScrollOffsetPreferenceKey.self, value: geometry.frame(in: .named("scroll")).origin)
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
            .ignoresSafeArea()
            .coordinateSpace(name: "scroll")
        }
        //        ScrollView(.horizontal, showsIndicators: true) {
        //            LazyHGrid(rows: model.gridItems, spacing: 10) {
        //                ForEach(model.participants) { participant in
        //                    ParticipantView(model: participant)
        //                        .frame(height: model.height)
        //                }
        //            }
        //        }
        //        .background(Color.black)
        //        .edgesIgnoringSafeArea(.all)
    }
}
