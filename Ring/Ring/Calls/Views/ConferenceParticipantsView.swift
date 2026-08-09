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

private enum RosterMetrics {
    static let margin: CGFloat = 20
    static let avatar: CGFloat = 44
    static let avatarSpacing: CGFloat = 12
    static let elementSpacing: CGFloat = 8
    static let textSpacing: CGFloat = 2
    static let verticalPadding: CGFloat = 8
    static let glyph: CGFloat = 24
    static let tapTarget: CGFloat = 44
    static let pendingAvatarOpacity: Double = 0.5

    static let textLeading = margin + avatar + avatarSpacing
    static let controlInset = margin - (tapTarget - glyph) / 2
}

private enum RosterTypography {
    static let sectionTitle = Font.headline
    static let headerAction = Font.title3
    static let rowControl = Font.body
    static let name = Font.subheadline.weight(.medium)
    static let detail = Font.caption
    static let status = Font.footnote
}

private extension View {
    func rosterRowInsets() -> some View {
        padding(.leading, RosterMetrics.margin)
            .padding(.trailing, RosterMetrics.controlInset)
            .padding(.vertical, RosterMetrics.verticalPadding)
    }
}

private struct RosterAvatar: View {
    let provider: AvatarProvider

    var body: some View {
        AvatarSwiftUIView(source: provider, sizeOverride: RosterMetrics.avatar)
    }
}

private struct RosterControlIcon: View {
    let systemImage: String
    let color: Color
    var font: Font = RosterTypography.rowControl

    var body: some View {
        Image(systemName: systemImage)
            .font(font)
            .foregroundColor(color)
            .frame(width: RosterMetrics.glyph, height: RosterMetrics.glyph)
            .frame(width: RosterMetrics.tapTarget, height: RosterMetrics.tapTarget)
            .contentShape(Rectangle())
    }
}

struct ConferenceParticipantsView: View {

    @ObservedObject var model: CallViewModel

    var body: some View {
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
                        rowSeparator
                    }
                }
                participantsHeader
                ForEach(model.participantRows) { row in
                    ParticipantRowView(
                        row: row,
                        avatar: model.avatarProvider(forUri: row.uri),
                        perform: { model.perform($0, on: row.id) })
                        .equatable()
                    rowSeparator
                }
            }
        }
        .background(Color.jamiCallBackdrop.opacity(0.3).ignoresSafeArea())
    }

    private var rowSeparator: some View {
        Divider()
            .padding(.leading, RosterMetrics.textLeading)
    }

    private func sectionHeader<Accessory: View>(
        _ title: String,
        @ViewBuilder accessory: () -> Accessory = { EmptyView() }) -> some View {
        HStack(spacing: RosterMetrics.elementSpacing) {
            Text(title)
                .font(RosterTypography.sectionTitle)
            Spacer()
            accessory()
        }
        .rosterRowInsets()
    }

    private var participantsHeader: some View {
        sectionHeader(L10n.Calls.inThisCall("\(model.participantRows.count)")) {
            HStack(spacing: 0) {
                if model.canModerateConference {
                    headerButton(L10n.Calls.gridLayout,
                                 systemImage: "square.grid.2x2",
                                 action: model.showGridLayout)
                }
                if model.canAddParticipant {
                    headerButton(L10n.Accessibility.Calls.Default.addParticipant,
                                 systemImage: "person.badge.plus",
                                 action: model.addParticipantTapped)
                }
            }
        }
    }

    private func headerButton(_ title: String,
                              systemImage: String,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            RosterControlIcon(systemImage: systemImage,
                              color: .white,
                              font: RosterTypography.headerAction)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(title)
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
        HStack(spacing: RosterMetrics.avatarSpacing) {
            RosterAvatar(provider: avatar)

            Text(displayName)
                .font(RosterTypography.name)
                .lineLimit(1)

            Spacer(minLength: RosterMetrics.elementSpacing)
            statusIcons
            if row.actions.isEmpty {
                Color.clear
                    .frame(width: RosterMetrics.tapTarget)
            } else {
                actionsMenu
            }
        }
        .rosterRowInsets()
        .contentShape(Rectangle())
    }

    private var displayName: String {
        let name = avatar.profileName.isEmpty ? row.uri.filterOutHost() : avatar.profileName
        return row.isLocal ? name.withYourselfSuffix() : name
    }

    @ViewBuilder private var statusIcons: some View {
        HStack(spacing: RosterMetrics.elementSpacing) {
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
            .font(RosterTypography.status)
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
            RosterControlIcon(systemImage: "ellipsis.circle", color: .secondary)
        }
        .accessibilityLabel(L10n.Calls.participantOptions(displayName))
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
        HStack(spacing: RosterMetrics.avatarSpacing) {
            RosterAvatar(provider: avatar)
                .opacity(RosterMetrics.pendingAvatarOpacity)

            VStack(alignment: .leading, spacing: RosterMetrics.textSpacing) {
                Text(displayName)
                    .font(RosterTypography.name)
                    .lineLimit(1)
                Text(row.progressText)
                    .font(RosterTypography.detail).foregroundColor(.secondary)
            }

            Spacer(minLength: RosterMetrics.elementSpacing)

            Button(action: cancel) {
                RosterControlIcon(systemImage: "phone.down.fill", color: .red)
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel(row.stopCallingLabel(displayName: displayName))
        }
        .rosterRowInsets()
    }

    private var displayName: String {
        avatar.profileName.isEmpty ? row.uri.filterOutHost() : avatar.profileName
    }

}
