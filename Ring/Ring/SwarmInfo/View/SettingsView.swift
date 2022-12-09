/*
 * Copyright (C) 2022 Savoir-faire Linux Inc. *
 *
 * Author: Alireza Toghiani Khorasgani alireza.toghiani@savoirfairelinux.com *
 *
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

    @SwiftUI.State var viewmodel: SwarmInfoViewModel!
    @SwiftUI.State private var ignoreSwarm = true
    @SwiftUI.State private var shouldShowColorPannel = false
    @SwiftUI.State private var showAlert = false
    @AppStorage("SWARM_COLOR") var swarmColor = Color.blue
    var id: String!
    var swarmType: String!

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                //                HStack {
                //                    Toggle(L10n.Swarm.ignoreSwarm, isOn: $ignoreSwarm)
                //                        .onChange(of: ignoreSwarm, perform: { value in
                //                            print("Value has changed : \(value)")
                //                            viewmodel.IgnoreSwarm(isOn: value)
                //                        })
                //                    }
                Button(action: {
                    showAlert = true
                }, label: {
                    HStack {
                        Text(L10n.Swarm.leaveConversation)
                            .multilineTextAlignment(.leading)
                        Spacer()
                    }
                }) .alert(isPresented: $showAlert) {
                    Alert(
                        title: Text(L10n.Swarm.confirmLeaveSwarm),
                        primaryButton: .destructive(Text(L10n.Swarm.leave)) {
                            viewmodel.leaveSwarm()
                        },
                        secondaryButton: .cancel()
                    )
                            }

                ColorPicker(L10n.Swarm.chooseColor, selection: $swarmColor)

                HStack {
                    Text(L10n.Swarm.typeOfSwarm)
                    Spacer()
                    Text(swarmType)
                }

                HStack {
                    Text(L10n.Swarm.identifier)
                        .padding(.trailing, 30)
                    Spacer()
                    Text(id)
                        .multilineTextAlignment(.trailing)
                        .truncationMode(.tail)
                        .lineLimit(1)
                }

            }
            .padding(.horizontal, 20)
        }
    }
}
