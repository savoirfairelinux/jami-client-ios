/*
 *  Copyright (C) 2022-2023 Savoir-faire Linux Inc.
 *
 * Author: Alireza Toghiani Khorasgani alireza.toghiani@savoirfairelinux.com *
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
struct LocationSharingView: View {

    @StateObject var model: MessagesListVM
    @Binding var coordinates: [(CLLocationCoordinate2D, UIImage)]
    @SwiftUI.State private var showCopyrightAlert = false

    var body: some View {
        GeometryReader { geometry in
            if model.isMapOpened {
                VStack {
                    ZStack(alignment: .center) {
                        VStack(spacing: 0) {
                            HStack {
                                Button {
                                    model.isMapOpened = false
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
                            .frame(width: UIScreen.main.bounds.size.width, height: 60)
                            .background(Color.gray)
                            .cornerRadius(radius: 20, corners: [.topLeft, .topRight])
                            ZStack(alignment: .bottom) {
                                MapView(coordinates: $coordinates)
                                HStack {
                                    Spacer()
                                    Button {
                                        showCopyrightAlert = true
                                    } label: {
                                        Image(systemName: "info")
                                            .foregroundColor(.white)
                                            .frame(width: 30, height: 30)
                                            .background(Color(UIColor.darkGray))
                                            .clipShape(Circle())
                                    }
                                }
                                .padding(16)
                            }
                        }

                        VStack {
                            Spacer()
                            Text(model.getMyLocationSharingRemainedTimeText())
                                .fontWeight(.semibold)
                                .font(.caption)
                                .padding([.leading, .trailing], 15)
                                .padding([.top, .bottom], 5)
                                .background(Color.black)
                                .foregroundColor(.white)
                                .cornerRadius(8)

                            if model.isAlreadySharingMyLocation() {
                                Button {
                                    model.stopSendingLocation()
                                    model.isMapOpened = false
                                } label: {
                                    HStack {
                                        Image(systemName: "paperplane.fill")
                                            .foregroundColor(.black)
                                        Text(L10n.Actions.stopLocationSharing)
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
                    }
                    .frame(width: UIScreen.main.bounds.size.width, height: UIScreen.main.bounds.size.height - 200)
                }
            } else {
                ZStack(alignment: .center) {
                    MapView(coordinates: $coordinates)
                        .frame(width: 250, height: 150)
                        .cornerRadius(15)
                        .onTapGesture {
                            model.isMapOpened = true
                        }
                    if model.isAlreadySharingMyLocation() {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Button {
                                    model.stopSendingLocation()
                                    model.isMapOpened = false
                                } label: {
                                    Text(L10n.Actions.stopLocationSharing)
                                        .fontWeight(.semibold)
                                        .font(.caption)
                                        .padding([.leading, .trailing], 15)
                                        .padding([.top, .bottom], 5)
                                        .background(Color.red)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                                Spacer()
                            }
                            .padding(.all, 10)
                        }
                    }
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button {
                                showCopyrightAlert = true
                            } label: {
                                Image(systemName: "info")
                                    .foregroundColor(.white)
                                    .frame(width: 30, height: 30)
                                    .background(Color(UIColor.darkGray))
                                    .clipShape(Circle())
                            }
                        }
                        .padding(.all, 10)
                    }
                }
                .frame(width: 200, height: 150)
            }
        }
        .alert(isPresented: $showCopyrightAlert) {
            Alert(title: Text("OpenStreetMap"), message: Text("Map data © OpenStreetMap contributors"), primaryButton: .default(Text("Open in Safari")) {
                showCopyrightAlert = false
                if let url = URL(string: "https://www.openstreetmap.org/copyright"),
                   UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url)
                }
            }, secondaryButton: .cancel())
        }
    }
}
