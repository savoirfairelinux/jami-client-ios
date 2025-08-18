/*
 *  Copyright (C) 2023 Savoir-faire Linux Inc.
 *
 *  Author: Binal Ahiya <binal.ahiya@savoirfairelinux.com>
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

struct AddMoreParticipantsInSwarm: View {
    @StateObject var viewmodel: SwarmInfoVM
    @SwiftUI.State var showAddMember = false
    @SwiftUI.State private var addMorePeople: UIImage = UIImage(asset: Asset.addPeopleInSwarm)!

    var body: some View {
        Button(action: {
            viewmodel.selections.removeAll()
            showAddMember = true
            viewmodel.updateContactList()
        }, label: {
            Image(uiImage: addMorePeople)
                .resizable()
                .renderingMode(.template)
                .aspectRatio(contentMode: .fill)
                .foregroundColor(Color(hex: viewmodel.finalColor)?.isLight(threshold: 0.8) ?? true ? Color(UIColor.jamiButtonDark) : Color.white)
                .frame(width: 30, height: 30, alignment: .center)
        })
        .frame(width: 50, height: 50, alignment: .center)
        .background(Color(hex: viewmodel.finalColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding()
        .sheet(isPresented: $showAddMember, onDismiss: {
            viewmodel.removeExistingSubscription()
        }, content: {
            NavigationView {
                VStack {
                    List {
                        ForEach(viewmodel.participantsRows) { contact in
                            ParticipantListCell(participant: contact, isSelected: viewmodel.selections.contains(contact.id)) {
                                if viewmodel.selections.contains(contact.id) {
                                    viewmodel.selections.removeAll(where: { $0 == contact.id })
                                } else {
                                    viewmodel.selections.append(contact.id)
                                }
                            }
                            .accessibilityElement()
                            .accessibilityLabel(Text(contact.name))
                            .accessibilityValue(viewmodel.selections.contains(contact.id) ? L10n.Swarm.inviteMembersSelected : L10n.Swarm.inviteMembersNotSelected)
                        }
                    }
                    .listStyle(PlainListStyle())

                    if !viewmodel.selections.isEmpty {
                        addMember()
                            .padding()
                    }
                }
                .navigationTitle(L10n.Swarm.inviteMembers) // 🔹 Title
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(L10n.Global.cancel) {
                            showAddMember = false
                        }
                        .foregroundColor(.jamiColor)
                    }
                }
            }
        })
    }

    func addMember() -> some View {
        return Button(action: {
            showAddMember = false
            viewmodel.addMember()
        }, label: {
            Text(L10n.Swarm.inviteMembers)
                .swarmButtonTextStyle()
        })
        .swarmButtonStyle()
        .accessibilityLabel(L10n.Swarm.inviteSelectedMembers)
    }
}
