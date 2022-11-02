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

struct MessagesList: View {
    @ObservedObject var list: MessagesListModel
    var body: some View {
        ScrollViewReader { _ in
            ScrollView {
                // GeometryReader { geo in
                LazyVStack {
                    // GeometryReader { _ in
                    ForEach(list.messagesModels) { message in
                        if #available(iOS 15.0, *) {
                            MessageRow(model: TestMessageModel(messageModel: message))
                                .onAppear {
                                    self.list.messagesAddedToScreen(messageId: message.id)
                                }
                                .onDisappear { self.list.messagesremovedFromScreen(messageId: message.id)
                                }
                                .listRowSeparator(.hidden)
                        } else {
                            MessageRow(model: TestMessageModel(messageModel: message))
                                .onAppear {
                                    self.list.messagesAddedToScreen(messageId: message.id)
                                }
                                .onDisappear { self.list.messagesremovedFromScreen(messageId: message.id)
                                }
                        }
                    }.onChange(of: list.messagesCount, perform: { _ in
                        // print("*******content size \(geo.size.height)")
                    })
                    //                    .background(
                    //                        GeometryReader { _ in
                    //                            // let _ = print(proxy.size.height)
                    //                            // print("*******content size \(rfvtr.size.height)")
                    //                            Color.green
                    //                                .onChange(of: list.messagesCount, perform: { _ in
                    //                                    // print("******* content ForEach size \(rfvtr.size.height)")
                    //                                })
                    //                        }
                    //                    )
                    //   }
                    // .offset(x: 0, y: geo.size.height)
                }
                .background(
                    GeometryReader { rfvtr in
                        // let _ = print(proxy.size.height)
                        // print("*******content size \(rfvtr.size.height)")
                        Color.blue
                            .onChange(of: list.messagesCount, perform: { _ in
                                list.updateSize(tableSize1: rfvtr.size.height)
                                print("******* content LazyVStack size \(rfvtr.size.height)")
                            })
                    }
                )
                .listRowBackground(Color.clear)
                //                .background(
                //                    GeometryReader { rfvtr in
                //                        // let _ = print(proxy.size.height)
                //                        // print("*******content size \(rfvtr.size.height)")
                //                        Color.red
                //                            .onChange(of: list.messagesCount, perform: { _ in
                //                                print("*******content size \(rfvtr.size.height)")
                //                            })
                //                    }
                //                )
                // .optionalList(enabled: true)
            }.offset(x: 0, y: -list.tableSize)
            //            .optionalList(enabled: false)
            .onChange(of: list.messagesCount, perform: { lastId in
                print("*******will scroll1 to \(list.lastId)")
                // scrollView.scrollTo(list.lastId)
            })
            //            .background(
            //                GeometryReader { _ in
            //                    // let _ = print(proxy.size.height)
            //                    // print("*******content size \(rfvtr.size.height)")
            //                    Color.red
            //                        .onChange(of: list.messagesCount, perform: { _ in
            //                            //                            print("******* content ScrollViewcontent size \(rfvtr.size.height)")
            //                        })
            //                }
            //            )
        }
    }
}

struct MessagesList_Previews: PreviewProvider {
    static var previews: some View {
        MessagesList(list: MessagesListModel())
    }
}
