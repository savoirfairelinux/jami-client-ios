/*
 * Copyright (C) 2019-2026 Savoir-faire Linux Inc.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA.
 */

import SwiftUI

struct ConferenceParticipantsView: View {

    @ObservedObject var model: CallViewModel

    var body: some View {
        VStack(spacing: 0) {
            Indicator(orientation: .horizontal)
                .padding(.top, 10)
            ScrollView {
                LazyVStack(spacing: 0) {
                    if !model.pendingRows.isEmpty {
                        sectionHeader(
                            L10n.Calls.callingParticipants("\(model.pendingRows.count)"))
                        ForEach(model.pendingRows) { row in
                            PendingParticipantRowView(
                                row: row,
                                avatar: model.avatarProvider(forUri: row.uri),
                                cancel: { model.cancelInvite(row.callId) })
                                .equatable()
                            Divider().padding(.leading, 68)
                        }
                    }
                    participantsHeader
                    ForEach(model.participantRows) { row in
                        ParticipantRowView(
                            row: row,
                            avatar: model.avatarProvider(forUri: row.uri),
                            perform: { model.perform($0, on: row.id) })
                            .equatable()
                        Divider().padding(.leading, 68)
                    }
                }
            }
        }
    }

    private func sectionHeader<Accessory: View>(
        _ title: String,
        @ViewBuilder accessory: () -> Accessory = { EmptyView() }) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.headline)
            Spacer()
            accessory()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private var participantsHeader: some View {
        sectionHeader(L10n.Calls.inThisCall("\(model.participantRows.count)")) {
            if model.canModerateConference {
                Button(action: model.showGridLayout) {
                    Label(L10n.Calls.gridLayout, systemImage: "square.grid.2x2")
                        .labelStyle(IconOnlyLabelStyle())
                        .imageScale(.large)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
            }
        }
    }
}

private struct ParticipantRowView: View, Equatable {

    let row: ConferenceParticipantRow
    @ObservedObject var avatar: AvatarProvider
    let perform: (ConferenceMenuItem) -> Void

    static func == (lhs: ParticipantRowView, rhs: ParticipantRowView) -> Bool {
        lhs.row == rhs.row
    }

    var body: some View {
        HStack(spacing: 12) {
            AvatarSwiftUIView(source: avatar, sizeOverride: 44)
                .frame(width: 44, height: 44)

            HStack(spacing: 6) {
                Text(displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                if row.isLocal {
                    Text(L10n.Account.me)
                        .font(.caption).foregroundColor(.secondary)
                }
            }

            Spacer(minLength: 8)
            statusIcons
            if !row.actions.isEmpty { actionsMenu }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    private var displayName: String {
        avatar.profileName.isEmpty ? row.uri.filterOutHost() : avatar.profileName
    }

    @ViewBuilder private var statusIcons: some View {
        HStack(spacing: 8) {
            if row.isSpeaking { icon("waveform", .green) }
            if row.isHandRaised { icon("hand.raised.fill", .yellow) }
            if row.isModerator { icon("checkmark.shield.fill", .secondary) }
            if row.isRecording { icon("record.circle", .red) }
            if row.isAudioMuted { icon("mic.slash.fill", .red) }
            if row.isVideoMuted { icon("video.slash.fill", .secondary) }
        }
    }

    private func icon(_ name: String, _ color: Color) -> some View {
        Image(systemName: name)
            .font(.footnote)
            .foregroundColor(color)
    }

    private var actionsMenu: some View {
        Menu {
            ForEach(row.actions, id: \.self) { item in
                Button {
                    perform(item)
                } label: {
                    Label(title(for: item), systemImage: symbol(for: item))
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .imageScale(.large)
                .foregroundColor(.secondary)
        }
    }

    private func title(for item: ConferenceMenuItem) -> String {
        if item == .setModerator && row.isModerator {
            return L10n.Calls.removeModerator
        }
        if item == .muteAudio && row.isAudioModeratorMuted {
            return L10n.Calls.unmuteAudio
        }
        return item.title
    }

    private func symbol(for item: ConferenceMenuItem) -> String {
        switch item {
        case .endCall: return "phone.down.fill"
        case .minimize: return "arrow.down.right.and.arrow.up.left"
        case .maximize: return "arrow.up.left.and.arrow.down.right"
        case .setModerator: return row.isModerator ? "shield.slash" : "checkmark.shield"
        case .muteAudio: return row.isAudioModeratorMuted ? "mic.fill" : "mic.slash.fill"
        case .lowerHand: return "hand.raised.slash"
        }
    }
}

private struct PendingParticipantRowView: View, Equatable {

    let row: PendingParticipantRow
    @ObservedObject var avatar: AvatarProvider
    let cancel: () -> Void

    static func == (lhs: PendingParticipantRowView, rhs: PendingParticipantRowView) -> Bool {
        lhs.row == rhs.row
    }

    var body: some View {
        HStack(spacing: 12) {
            AvatarSwiftUIView(source: avatar, sizeOverride: 44)
                .frame(width: 44, height: 44)
                .opacity(0.5)

            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text(row.progressText)
                    .font(.caption).foregroundColor(.secondary)
            }

            Spacer(minLength: 8)

            Button(action: cancel) {
                Image(systemName: "phone.down.fill")
                    .imageScale(.medium)
                    .foregroundColor(.red)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel(row.stopCallingLabel(displayName: displayName))
        }
        .padding(.leading, 20)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
    }

    private var displayName: String {
        avatar.profileName.isEmpty ? row.uri.filterOutHost() : avatar.profileName
    }

}
