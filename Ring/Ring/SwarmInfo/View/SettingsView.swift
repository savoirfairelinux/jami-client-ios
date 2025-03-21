/*
 * Copyright (C) 2022 Savoir-faire Linux Inc. *
 *
 * Author: Alireza Toghiani Khorasgani alireza.toghiani@savoirfairelinux.com *
 * Author: Binal Ahiya binal.ahiya@savoirfairelinux.com *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version. *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details. *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

import SwiftUI

struct SettingsView: View {

    @ObservedObject var viewmodel: SwarmInfoVM
    let stateEmitter: ConversationStatePublisher

    enum PresentingAlert: Identifiable {
        case removeConversation
        case blockContact

        var id: Self { self }
    }

    @SwiftUI.State private var ignoreSwarm = true
    @SwiftUI.State private var shouldShowColorPannel = false
    @SwiftUI.State private var showQRcode = false
    @SwiftUI.State private var presentingAlert: PresentingAlert?
    var id: String!
    var swarmType: String!
    // swiftlint:disable closure_body_length
    var body: some View {
        Form {
            if let conversation = viewmodel.conversation,
               conversation.isCoredialog(),
               let jamiId = conversation.getParticipants().first?.jamiId {
                Section(header: Text("Contact")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Jami id:")
                        if #available(iOS 15.0, *) {
                            Text(jamiId)
                                .font(.footnote)
                                .multilineTextAlignment(.trailing)
                                .truncationMode(.middle)
                                .lineLimit(1)
                                .foregroundColor(Color(UIColor.secondaryLabel))
                                .textSelection(.enabled)

                        } else {
                            Text(jamiId)
                                .font(.footnote)
                                .multilineTextAlignment(.trailing)
                                .truncationMode(.middle)
                                .lineLimit(1)
                                .foregroundColor(Color(UIColor.secondaryLabel))
                        }

                        HStack(spacing: 0) {
                            Button(action: {
                                showQRcode = true
                            }) {
                                Image(systemName: "qrcode")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 20, height: 20)
                                    .foregroundColor(Color(UIColor.secondaryLabel))
                                    .padding(5)
                                    .frame(maxWidth: .infinity)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color(UIColor.systemGray4), lineWidth: 1)
                                    )
                            }
                            .padding(.horizontal, 5)
                            .sheet(isPresented: $showQRcode) {
                                QRCodePresenter(isPresented: $showQRcode, jamiId: jamiId, accessibilityLabel: "Contact's qr code")
                            }
                            .buttonStyle(PlainButtonStyle())

                            ShareButtonView(infoToShare: "You can add this contact \(jamiId) on the Jami distributed communication platform: https://jami.net") {
                                Image(systemName: "square.and.arrow.up")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 20, height: 20)
                                    .foregroundColor(Color(UIColor.secondaryLabel))
                                    .padding(5)
                                    .frame(maxWidth: .infinity)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color(UIColor.systemGray4), lineWidth: 1)
                                    )
                                    .padding(.horizontal, 5)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.vertical, 8)
                    }

                    Button(action: {
                        presentingAlert = .blockContact
                    }, label: {
                        Text(L10n.Global.blockContact)
                            .multilineTextAlignment(.leading)
                    })
                }
            }

            Section(header: Text("Conversation")) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Conversation Id:")
                    if #available(iOS 15.0, *) {
                        Text(id)
                            .font(.footnote)
                            .multilineTextAlignment(.trailing)
                            .truncationMode(.middle)
                            .lineLimit(1)
                            .foregroundColor(Color(UIColor.secondaryLabel))
                            .textSelection(.enabled)
                    } else {
                        Text(id)
                            .font(.footnote)
                            .multilineTextAlignment(.trailing)
                            .truncationMode(.middle)
                            .lineLimit(1)
                            .foregroundColor(Color(UIColor.secondaryLabel))
                    }
                }
                HStack {
                    Text(L10n.Swarm.typeOfSwarm)
                    Spacer()
                    Text(swarmType)
                        .foregroundColor(Color(UIColor.secondaryLabel))
                }
                HStack {
                    Text(L10n.Swarm.chooseColor)
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(Color(hex: viewmodel.finalColor)!)
                            .frame(width: 15, height: 15)
                            .onTapGesture(perform: {
                                withAnimation {
                                    viewmodel.showColorSheet.toggle()
                                    viewmodel.hideShowBackButton(colorPicker: viewmodel.showColorSheet)
                                }
                            })
                            .onChange(of: viewmodel.selectedColor, perform: { newValue in
                                viewmodel.updateSwarmColor(selectedColor: newValue)
                            })
                            .padding(10)
                        Circle()
                            .stroke(Color(hex: viewmodel.finalColor)!, lineWidth: 5)
                            .frame(width: 25, height: 25)
                    }
                }
                Button(action: {
                    presentingAlert = .removeConversation
                }, label: {
                        Text(L10n.Swarm.leaveConversation)
                            .multilineTextAlignment(.leading)
                })
                .alert(item: $presentingAlert) { alert in
                    switch alert {
                    case .removeConversation:
                        return Alert(
                            title: Text(L10n.Swarm.confirmLeaveConversation),
                            primaryButton: .destructive(Text(L10n.Swarm.leave)) {
                                viewmodel.leaveSwarm(stateEmitter: stateEmitter)
                            },
                            secondaryButton: .cancel()
                        )
                    case .blockContact:
                        return Alert(
                            title: Text(L10n.Alerts.confirmBlockContact),
                            primaryButton: .destructive(Text(L10n.Global.block)) {
                                viewmodel.blockContact(stateEmitter: stateEmitter)
                            },
                            secondaryButton: .cancel()
                        )
                    }
                }
            }
        }
    }
}
struct CustomColorPicker: View {
    @Binding var selectedColor: String
    @Binding var currentColor: String
    var body: some View {
        GeometryReader { geometry in
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(Constants.swarmColors, id: \.self) { color in
                        CircleView(colorString: color, selectedColor: $selectedColor)
                    }
                }
                .padding()
                .frame(minWidth: geometry.size.width, minHeight: geometry.size.height)
            }
        }
    }
}
struct CircleView: View {
    @SwiftUI.State var colorString: String
    @Binding var selectedColor: String

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: colorString)!)
                .frame(width: 40, height: 40)
                .onTapGesture(perform: {
                    selectedColor = colorString
                })
                .padding(5)
            if selectedColor == colorString {
                Circle()
                    .stroke(Color(hex: colorString)!, lineWidth: 5)
                    .frame(width: 50, height: 50)
            }
        }
    }
}

struct BorderButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(configuration.isPressed ? Color(UIColor.systemGray5) : Color.clear)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
