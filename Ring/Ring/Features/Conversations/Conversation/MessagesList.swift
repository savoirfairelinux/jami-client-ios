//
//  MessagesList.swift
//  Ring
//
//  Created by kateryna on 2022-09-26.
//  Copyright © 2022 Savoir-faire Linux. All rights reserved.
//

import SwiftUI

struct ConditionalListView: ViewModifier {

    let isEnable: Bool

    func body(content: Content) -> some View {
        Group {
            if isEnable {
                List {
                    content
                }
            } else {
                LazyVStack {
                    Spacer()
                    content
                }
            }
        }
    }
}

// private struct ScrollOffsetPreferenceKey: PreferenceKey {
//    static var defaultValue: CGPoint = .zero
//
//    static func reduce(value: inout CGPoint, nextValue: () -> CGPoint) {}
// }

// struct ScrollView<Content: View>: View {
//    let axes: Axis.Set
//    let showsIndicators: Bool
//    let offsetChanged: (CGPoint) -> Void
//    let content: Content
//
//    init(
//        axes: Axis.Set = .vertical,
//        showsIndicators: Bool = true,
//        offsetChanged: @escaping (CGPoint) -> Void = { _ in },
//        @ViewBuilder content: () -> Content
//    ) {
//        self.axes = axes
//        self.showsIndicators = showsIndicators
//        self.offsetChanged = offsetChanged
//        self.content = content()
//    }
//
//    var body: some View {
//        SwiftUI.ScrollView(axes, showsIndicators: showsIndicators) {
//            GeometryReader { geometry in
//                Color.clear.preference(
//                    key: ScrollOffsetPreferenceKey.self,
//                    value: geometry.frame(in: .named("scrollView")).origin
//                )
//            }.frame(width: 0, height: 0)
//            content
//        }
//        .coordinateSpace(name: "scrollView")
//        .onPreferenceChange(ScrollOffsetPreferenceKey.self, perform: offsetChanged)
//    }
// }

extension View {
    func optionalList(enabled: Bool) -> some View {
        modifier(ConditionalListView(isEnable: enabled))
    }
}

// struct Location: Identifiable {
//    let id: UUID = UUID()
//    var name: String
// }

struct MessagesList: View {
    @ObservedObject var list: MessagesListModel
    //    @State private var locations = ["Beach", "Forest", "Desert", "Desert", "Desert", "Desert", "Desert", "Desert",
    //                                    "Desert", "Desert", "Desert", "Desert", "Desert", "Desert", "Desert", "Desert", "Desert",
    //                                    "Desert", "Desert", "Desert", "Desert", "Desert", "Desert", "Desert", "Desert", "Desert",
    //                                    "Desert", "Desert", "Desert", "Desert", "Desert2", "Desert1"]
    //    @State var locations = [Location(name: "Beach1"), Location(name: "Beach2"), Location(name: "Beach3"), Location(name: "Beach4"), Location(name: "Beach5"),
    //                            Location(name: "Beach6"), Location(name: "Beach7"), Location(name: "Beac8h"),
    //                            Location(name: "Beach9"), Location(name: "Beach"), Location(name: "Beach"), Location(name: "Beach"), Location(name: "Beach"),
    //                            Location(name: "Beach"), Location(name: "Beach"), Location(name: "Beach"), Location(name: "Beach"),
    //                            Location(name: "Beach"),
    //                            Location(name: "Beach"), Location(name: "Beach"),
    //                            Location(name: "Beach"), Location(name: "Beach"),
    //                            Location(name: "Beach"), Location(name: "Beach6"),
    //                            Location(name: "Beach"), Location(name: "Beach"), Location(name: "Beach"), Location(name: "Beach"),
    //                            Location(name: "Beach"), Location(name: "Beach6"), Location(name: "Beach"), Location(name: "Beach4")]

    //    @State private var locations = ["Beach", "Forest", "Desert", "Desert", "Desert", "Desert", "Desert", "Desert",
    //                                    "Desert", "Desert", "Desert", "Desert", "Desert", "Desert", "Desert", "Desert", "Desert",
    //                                    "Desert", "Desert", "Desert", "Desert", "Desert", "Desert", "Desert", "Desert", "Desert",
    //                                    "Desert", "Desert", "Desert", "Desert", "Desert", "Desert"]

    var body: some View {
        NavigationView {
            ScrollViewReader { scrollView in
                GeometryReader { outerProxy in
                    List {
                        //                ForEach(list.messagesModels) { message in
                        //                    MessageRow(model: TestMessageModel(messageModel: message))
                        //                }
                        // 2.
                        ForEach(list.locations) { location in
                            GeometryReader { geometry in
                                Text(location.name)
                                    .onChange(of: geometry.frame(in: .named("scrollView"))) { imageRect in
                                        if isInView(innerRect: imageRect, isIn: outerProxy) {
                                            self.list.locationAddedToScreen(messageId: location.id)
                                        } else {
                                            self.list.locationremovedFromScreen(messageId: location.id)
                                        }
                                    }
                            }
                            //                            .onAppear {
                            //                                self.list.locationAddedToScreen(messageId: location.id)
                            //                            }
                            //                            .onDisappear { self.list.locationremovedFromScreen(messageId: location.id)
                            //                            }
                        }
                    }.onChange(of: list.locationsCount, perform: { _ in
                        scrollView.scrollTo(list.lastUUID)

                    })
                }
            }
            .navigationBarTitle(Text("Locations"))
            // 3.
            .navigationBarItems(trailing: Button(action: {
                self.addRow()
            }) {
                Image(systemName: "plus")
            })
        }
    }

    private func addRow() {
        list.updateLocations()
    }

    private func isInView(innerRect: CGRect, isIn outerProxy: GeometryProxy) -> Bool {
        let innerOrigin = innerRect.origin.x
        let imageWidth = innerRect.width
        let scrollOrigin = outerProxy.frame(in: .global).origin.x
        let scrollWidth = outerProxy.size.width
        if innerOrigin + imageWidth < scrollOrigin + scrollWidth && innerOrigin + imageWidth > scrollOrigin ||
            innerOrigin + imageWidth > scrollOrigin && innerOrigin < scrollOrigin + scrollWidth {
            return true
        }
        return false
    }

}

struct MessagesList_Previews: PreviewProvider {
    static var previews: some View {
        MessagesList(list: MessagesListModel())
    }
}
