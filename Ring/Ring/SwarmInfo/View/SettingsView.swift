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

    enum PresentingAlert: Identifiable {
        case removeConversation
        case blockContact

        var id: Self { self }
    }

    @StateObject var viewmodel: SwarmInfoVM
    @SwiftUI.State private var ignoreSwarm = true
    @SwiftUI.State private var shouldShowColorPannel = false
    @SwiftUI.State private var presentingAlert: PresentingAlert?
    var id: String!
    var swarmType: String!

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.Swarm.identifier)
                        .padding(.trailing, 30)
                    if #available(iOS 15.0, *) {
                        Text(id)
                            .font(.footnote)
                            .multilineTextAlignment(.trailing)
                            .truncationMode(.tail)
                            .lineLimit(1)
                            .foregroundColor(Color(UIColor.secondaryLabel))
                            .textSelection(.enabled)
                    } else {
                        Text(id)
                            .font(.footnote)
                            .multilineTextAlignment(.trailing)
                            .truncationMode(.tail)
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
                            .frame(width: 20, height: 20)
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
                            .frame(width: 30, height: 30)
                    }
                }
                Button(action: {
                    presentingAlert = .removeConversation
                }, label: {
                    HStack {
                        Text(L10n.Swarm.leaveConversation)
                            .multilineTextAlignment(.leading)
                        Spacer()
                    }
                })
                .alert(item: $presentingAlert) { alert in
                    switch alert {
                        case .removeConversation:
                            return Alert(
                                title: Text(L10n.Swarm.confirmLeaveSwarm),
                                primaryButton: .destructive(Text(L10n.Swarm.leave)) {
                                    viewmodel.leaveSwarm()
                                },
                                secondaryButton: .cancel()
                            )
                        case .blockContact:
                            return Alert(
                                title: Text(L10n.Alerts.confirmBlockContact),
                                primaryButton: .destructive(Text(L10n.Global.block)) {
                                    viewmodel.blockContact()
                                },
                                secondaryButton: .cancel()
                            )
                    }
                }

                if viewmodel.conversation?.isCoredialog() ?? false {
                    Button(action: {
                        presentingAlert = .blockContact
                    }, label: {
                        HStack {
                            Text(L10n.Global.blockContact)
                                .multilineTextAlignment(.leading)
                                .padding(.top)
                            Spacer()
                        }
                    })
                }
            }
            .padding(.horizontal, 20)
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
