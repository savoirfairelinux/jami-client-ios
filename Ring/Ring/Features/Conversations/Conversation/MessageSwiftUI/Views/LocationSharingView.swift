//
//  LocationSharingView.swift
//  Ring
//
//  Created by Alireza Toghiani on 1/13/23.
//  Copyright © 2023 Savoir-faire Linux. All rights reserved.
//

import SwiftUI

// swiftlint:disable closure_body_length
struct LocationSharingView: View {

    @StateObject var model: MessagesListVM
    @SwiftUI.State var coordinates: [(CLLocationCoordinate2D, UIImage)]

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
                            .frame(width: UIScreen.main.bounds.size.width, height: 50)
                            .background(Color.gray)
                            .cornerRadius(radius: 20, corners: [.topLeft, .topRight])
                            MapView(coordinates: coordinates)
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
                                model.stopSendingLocation()
                                model.isMapOpened = false
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
                .flipped()
            } else {
                ZStack(alignment: .center) {
                    MapView(coordinates: coordinates)
                        .frame(width: 250, height: 150)
                        .cornerRadius(15)
                        .onTapGesture {
                            model.isMapOpened = true
                        }
                    VStack {
                        Spacer()
                        Button {
                            model.stopSendingLocation()
                            model.isMapOpened = false
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
                .flipped()
            }
        }
    }
}
