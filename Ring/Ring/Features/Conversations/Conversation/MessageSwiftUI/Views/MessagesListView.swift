/*
 *  Copyright (C) 2022 Savoir-faire Linux Inc.
 *
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
 *  Author: Alireza Toghiani Khorasgani alireza.toghiani@savoirfairelinux.com
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

// swiftlint:disable closure_body_length
struct MessagesListView: View {

    @StateObject var list: MessagesListVM
    @SwiftUI.State var isMapOpened: Bool = false

    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { scrollView in
                ZStack(alignment: isMapOpened ? .bottom : .top) {
                    ScrollView {
                        LazyVStack {
                            ForEach(list.messagesModels) { message in
                                MessageRowView(messageModel: message, model: message.messageRow)
                                    .onAppear { self.list.messagesAddedToScreen(messageId: message.id) }
                                    .onDisappear { self.list.messagesremovedFromScreen(messageId: message.id) }
                            }
                        }
                        .listRowBackground(Color.clear)
                        .onReceive(list.$needScroll, perform: { (updated) in
                            if updated {
                                scrollView.scrollTo(list.lastMessageOnScreen)
                                list.needScroll = false
                            }
                        })
                    }

                    let myContactsLocation = list.myContactsLocation ?? CLLocationCoordinate2D(latitude: 37.785834, longitude: -122.406417)
                    let myLocation = list.myCoordinate ?? CLLocationCoordinate2D(latitude: 37.785867, longitude: -122.406417)
                    //                if let myLocation = list.myCoordinate , let myContactsLocation = list.myContactsLocation {
                    if isMapOpened {
                        VStack {

                            ZStack(alignment: .center) {
                                VStack(spacing: 0) {
                                    HStack {
                                        Button {
                                            isMapOpened = false
                                        } label: {
                                            Image(systemName: "xmark")
                                                .foregroundColor(.white)
                                                .padding()
                                        }
                                        Text("Location Sharing")
                                            .fontWeight(.semibold)
                                            .font(.title3)
                                            .foregroundColor(.white)
                                        Spacer()
                                    }
                                    .frame(width: UIScreen.main.bounds.size.width, height: 50)
                                    .background(Color.gray)
                                    .cornerRadius(radius: 20, corners: [.topLeft, .topRight])
                                    MapView(coordinates: [myContactsLocation, myLocation])
                                }

                                VStack {
                                    Spacer()
                                    Button {

                                    } label: {
                                        Text("10 mins")
                                            .fontWeight(.semibold)
                                            .font(.caption)
                                            .padding([.leading, .trailing], 15)
                                            .padding([.top, .bottom], 5)
                                            .background(Color.black)
                                            .foregroundColor(.white)
                                            .cornerRadius(8)
                                    }

                                    Button {
                                        isMapOpened = false
                                    } label: {
                                        HStack {
                                            Image(systemName: "paperplane.fill")
                                                .foregroundColor(.black)
                                            Text("Stop Sharing")
                                                .font(.callout)
                                        }
                                        .padding([.leading, .trailing], 15)
                                        .padding([.top, .bottom], 15)
                                        .background(Color.red)
                                        .foregroundColor(.black)
                                        .cornerRadius(20)
                                    }
                                    .padding(.bottom, geometry.size.height / 8)

                                }
                            }
                            .frame(width: UIScreen.main.bounds.size.width, height: UIScreen.main.bounds.size.height - 120)
                        }
                    } else {
                        ZStack(alignment: .center) {
                            MapView(coordinates: [myContactsLocation, myLocation])
                                .frame(width: 250, height: 150)
                                .cornerRadius(15)
                                .onTapGesture {
                                    isMapOpened = true
                                }
                            VStack {
                                Spacer()
                                Button {

                                } label: {
                                    Text("Stop Sharing")
                                        .fontWeight(.semibold)
                                        .font(.caption)
                                        .padding([.leading, .trailing], 15)
                                        .padding([.top, .bottom], 5)
                                        .background(Color.red)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                                .padding(.all, 10)
                            }
                        }
                        .frame(width: 200, height: 150)
                    }
                    //                }
                }
            }
        }
    }
}
