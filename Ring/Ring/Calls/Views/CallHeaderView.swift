/*
 * Copyright (C) 2017-2026 Savoir-faire Linux Inc.
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

struct CallHeaderView: View {

    private enum Metrics {
        static let minimumHeight: CGFloat = 46
        static let verticalPadding: CGFloat = 8
        static let lineSpacing: CGFloat = 4
        static let spacing: CGFloat = 8
        static let avatar: CGFloat = 22
        static let avatarOverlap: CGFloat = -7
        static let avatarBorder: CGFloat = 1
    }

    @ObservedObject var model: CallViewModel
    let horizontalInset: CGFloat

    private var header: CallHeaderModel { model.header }

    private var isTappable: Bool { header.showsRoster || model.canAddParticipant }

    var body: some View {
        Group {
            if isTappable {
                Button(action: showParticipants) {
                    content
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityHint(L10n.Accessibility.Conference.showParticipants)
            } else {
                content
            }
        }
    }

    private var content: some View {
        VStack(spacing: Metrics.lineSpacing) {
            HStack(spacing: Metrics.spacing) {
                if !header.avatars.isEmpty {
                    avatars
                }
                if header.isRecording {
                    RecordingIndicator()
                }
                Text(header.title)
                    .font(.body.weight(.medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .truncationMode(header.titleIsIdentifier ? .middle : .tail)
                    .layoutPriority(1)
                if isTappable {
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.white.opacity(0.7))
                        .accessibilityHidden(true)
                }
            }
            Text(model.statusLine)
                .font(.footnote.monospacedDigit())
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(1)
        }
        .padding(.horizontal, horizontalInset)
        .padding(.vertical, Metrics.verticalPadding)
        .frame(minHeight: Metrics.minimumHeight)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityValue(header.isInviting ? L10n.Calls.inviting : "")
    }

    private func showParticipants() {
        model.showsParticipants = true
    }

    private var avatars: some View {
        HStack(spacing: Metrics.avatarOverlap) {
            ForEach(Array(header.avatars.enumerated()), id: \.element.uri) { index, avatar in
                face(avatar).zIndex(-Double(index))
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder private func face(_ avatar: CallHeaderAvatar) -> some View {
        let portrait = AvatarSwiftUIView(source: model.avatarProvider(forUri: avatar.uri),
                                         sizeOverride: Metrics.avatar)
        if avatar.isPending {
            portrait.overlay(ring(Color.jami)).modifier(AwaitedFace())
        } else {
            portrait.overlay(ring(Color.white.opacity(0.3)))
        }
    }

    private func ring(_ color: Color) -> some View {
        Circle().strokeBorder(color, lineWidth: Metrics.avatarBorder)
    }

}

private struct RecordingIndicator: View {

    private enum Metrics {
        static let size: CGFloat = 8
        static let dimmedOpacity: Double = 0.35
        static let period: TimeInterval = 0.8
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @SwiftUI.State private var isDimmed = false

    var body: some View {
        Circle()
            .fill(Color.red)
            .frame(width: Metrics.size, height: Metrics.size)
            .opacity(reduceMotion ? 1 : (isDimmed ? Metrics.dimmedOpacity : 1))
            .accessibilityLabel(L10n.Calls.peerRecording)
            .onAppear { updateAnimation(reduceMotion: reduceMotion) }
            .onChange(of: reduceMotion) { updateAnimation(reduceMotion: $0) }
    }

    private func updateAnimation(reduceMotion: Bool) {
        guard !reduceMotion else {
            isDimmed = false
            return
        }
        withAnimation(.easeInOut(duration: Metrics.period)
                        .repeatForever(autoreverses: true)) {
            isDimmed = true
        }
    }
}

private struct AwaitedFace: ViewModifier {

    private enum Metrics {
        static let dimmed: Double = 0.45
        static let period: Double = 1
    }

    @SwiftUI.State private var awaiting = false

    func body(content: Content) -> some View {
        content
            .opacity(awaiting ? Metrics.dimmed : 1)
            .onAppear {
                withAnimation(.easeInOut(duration: Metrics.period)
                                .repeatForever(autoreverses: true)) {
                    awaiting = true
                }
            }
    }
}
