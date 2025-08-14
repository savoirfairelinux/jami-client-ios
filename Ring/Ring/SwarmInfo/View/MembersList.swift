/*
 * Copyright (C) 2022 - 2025 Savoir-faire Linux Inc. *
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

struct MemberList: View {
    // MARK: - Properties
    @StateObject var viewModel: SwarmInfoVM
    @SwiftUI.State private var editMode = EditMode.inactive

    // MARK: - Body
    var body: some View {
        List {
            Section(header: Text(L10n.Swarm.members)) {
                ForEach(viewModel.swarmInfo.participants.value, id: \.self) { participant in
                    MemberItem(
                        participant: participant,
                        isInvited: participant.role == .invited
                    )
                    .deleteDisabled(participant.role == .admin)
                }
                .onDelete(perform: viewModel.isAdmin ? delete : nil)
            }
        }
        .environment(\.editMode, $editMode)
        .onChange(of: viewModel.swarmInfo.participants.value) { _ in
            if editMode == .active {
                editMode = .inactive
            }
        }
    }

    // MARK: - Methods
    private func delete(at indexSet: IndexSet) {
        viewModel.removeMember(indexOffset: indexSet)
    }
}

struct MemberItem: View {
    // MARK: - Properties
    let participant: ParticipantInfo
    let isInvited: Bool

    private var displayName: String {
        participant.finalName.value.isEmpty ? participant.jamiId : participant.finalName.value
    }

    private var roleText: String {
        participant.role == .member ? "" : participant.role.stringValue
    }

    // MARK: - Body
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            profileImage
            nameLabel
            Spacer()
            roleLabel
        }
        .opacity(isInvited ? 0.5 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(displayName), \(roleText)")
        .accessibilityHint(isInvited ? L10n.Swarm.invited : "")
    }

    // MARK: - View Components
    private var profileImage: some View {
        return AvatarSwiftUIView(source: participant.provider)
            .frame(width: Constants.defaultAvatarSize, height: Constants.defaultAvatarSize)
    }

    private var nameLabel: some View {
        Text(displayName)
            .lineLimit(1)
            .truncationMode(.middle)
    }

    private var roleLabel: some View {
        Text(roleText)
            .font(.system(.callout, design: .rounded))
            .fontWeight(.light)
            .foregroundColor(.secondary)
    }
}
