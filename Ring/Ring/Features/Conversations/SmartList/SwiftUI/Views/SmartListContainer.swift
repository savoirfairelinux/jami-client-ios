//
//  ConversationsAndRequestsSegment.swift
//  Ring
//
//  Created by kateryna on 2024-03-19.
//  Copyright © 2024 Savoir-faire Linux. All rights reserved.
//

import SwiftUI

struct RowSeparatorHiddenModifier: ViewModifier {
    func body(content: Content) -> some View {
        // Check for iOS 15 and above
        if #available(iOS 15.0, *) {
            content
                .listRowSeparator(.hidden)
        } else {
            content
        }
    }
}

extension View {
    func hideRowSeparator() -> some View {
        self.modifier(RowSeparatorHiddenModifier())
    }
}

struct SmartListContainer: View {
    @ObservedObject var model: ConversationsViewModel
    var mode: SearchMode
    @Binding var isSearchBarActive: Bool
    @Binding var isNewMessageViewPresented: Bool
    let dismissAction: (() -> Void)?
    var body: some View {
        List {
            if !model.searchQuery.isEmpty {
                if model.temporaryConversation != nil {
                    Text("Publick directory")
                        .hideRowSeparator()
                    TempConversationsView(model: model)
                } else if !model.jamsSearchResult.isEmpty {
                    Text("Search Result")
                        .hideRowSeparator()
                    jamsSearchResultView(model: model)
                } else if model.searchingLabel == "Searching…" {
                    HStack {
                        Spacer()
                        SwiftUI.ProgressView()
                        Spacer()
                    }
                        .hideRowSeparator()
                } else if model.searchingLabel == "Username not found" {
                    Text(model.searchingLabel)
                        .hideRowSeparator()
                } else if model.searchingLabel == "Invalid id" {
                    Text(model.searchingLabel)
                        .hideRowSeparator()
                }
            }
            if mode == .smartList {
                // requests
                if model.unreadRequests > 0 && !isSearchBarActive {
                    Button {
                        model.openRequests()
                    } label: {
                        HStack {
                            Spacer()
                                .frame(width: 15)
                            Image(systemName: "envelope.badge")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 25, height: 25)
                                .foregroundColor(.white)
                            Spacer()
                                .frame(width: 15)
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Invitation received")
                                    .font(.footnote)
                                    .bold()
                                    .foregroundColor(.white)
                                Text(model.requestsTitle)
                                    .lineLimit(1)
                                    .font(.footnote)
                                    .foregroundColor(.white)
                            }
                            Spacer()
                                .frame(width: 15)
                            Spacer()
                            Text("\(model.unreadRequests)")
                                .font(.footnote)
                                .bold()
                                .foregroundColor(.white)
                                .padding(.vertical, 5)
                                .padding(.horizontal, 8)
                                .background(Color(UIColor.jamiMain))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                .padding(.vertical, 20)
                            Spacer()
                                .frame(width: 15)

                        }
                        .frame(maxWidth: .infinity)
                        .background(Color(UIColor(named: "jami")!))
                        .cornerRadius(12)
                        .padding(0)
                        .hideRowSeparator()
                    }
                    .padding(0)
                    .hideRowSeparator()
                    .listRowInsets(EdgeInsets(top: 0, leading: 15, bottom: 5, trailing: 15))
                }
            } else {
                if !isSearchBarActive {
                    HStack {
                            HStack {
                                Image(systemName: "qrcode")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 20, height: 20)
                                    .foregroundColor(Color(UIColor(named: "jamiMain")!))
                                Spacer()
                                    .frame(width: 15)
                                Text("Add Contact")
                                    .lineLimit(1)

                            }
                            .padding()
                            .frame(height: 35)
                            .background(Color(UIColor(named: "donationBanner")!))
                            .cornerRadius(12)
                            .onTapGesture {
                                model.scanQRCode()
                            }
                        Spacer()
                            HStack {
                                Image(systemName: "person.2")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 20, height: 20)
                                    .foregroundColor(Color(UIColor(named: "jamiMain")!))
                                Spacer()
                                    .frame(width: 15)
                                Text("Create Swarm")
                                    .lineLimit(1)

                            }
                            .padding()
                            .frame(height: 35)
                            .background(Color(UIColor(named: "donationBanner")!))
                            .cornerRadius(12)
                            .onTapGesture {
                                model.createSwarm()
                            }

                    }
                    .hideRowSeparator()
                }
            }

            if isSearchBarActive && !model.conversations.isEmpty {
                Text("Conversations")
                    .hideRowSeparator()
            }
            ConversationsView(model: model, mode: mode, isNewMessageViewPresented: $isNewMessageViewPresented, dismissAction: dismissAction)
        }
        .listStyle(.plain)
    }
}

