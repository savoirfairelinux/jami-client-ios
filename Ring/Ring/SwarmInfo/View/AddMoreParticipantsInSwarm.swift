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

struct InviteParticipantsSheet: View {
    @ObservedObject var viewModel: SwarmInfoVM
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack {
                List {
                    ForEach(viewModel.participantsRows) { contact in
                        ParticipantListCell(participant: contact, isSelected: viewModel.selections.contains(contact.id)) {
                            if viewModel.selections.contains(contact.id) {
                                viewModel.selections.removeAll(where: { $0 == contact.id })
                            } else {
                                viewModel.selections.append(contact.id)
                            }
                        }
                        .accessibilityElement()
                        .accessibilityLabel(Text(contact.name))
                        .accessibilityValue(viewModel.selections.contains(contact.id) ? L10n.Swarm.inviteMembersSelected : L10n.Swarm.inviteMembersNotSelected)
                    }
                }
                .listStyle(PlainListStyle())

                if !viewModel.selections.isEmpty {
                    addMember()
                        .padding()
                }
            }
            .navigationTitle(L10n.Swarm.inviteMembers)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Global.cancel) {
                        dismiss()
                    }
                }
            }
        }
        .accentColor(.jami)
    }

    func addMember() -> some View {
        return Button(action: {
            dismiss()
            viewModel.addMember()
        }, label: {
            Text(L10n.Swarm.inviteMembers)
                .swarmButtonTextStyle()
        })
        .swarmButtonStyle()
        .accessibilityLabel(L10n.Swarm.inviteSelectedMembers)
    }
}
