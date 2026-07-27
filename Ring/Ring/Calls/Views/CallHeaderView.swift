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
        static let maximumWidth: CGFloat = 420
        static let outerInset: CGFloat = 26
        static let horizontalPadding: CGFloat = 20
        static let verticalPadding: CGFloat = 10
        static let lineSpacing: CGFloat = 4
        static let spacing: CGFloat = 8
        static let avatar: CGFloat = 22
        static let avatarOverlap: CGFloat = -7
        static let avatarBorder: CGFloat = 1.5
        static let recordingDot: CGFloat = 8
    }

    @ObservedObject var model: CallViewModel

    private var header: CallHeaderModel { model.header }

    /// The cap bounds the width *proposed* to the capsule, which then shrink-wraps
    /// within it — so a long name truncates instead of stretching the pill.
    var body: some View {
        capsule
            .frame(maxWidth: Metrics.maximumWidth)
            .padding(.horizontal, Metrics.outerInset)
    }

    /// Sized by the layout rather than by its content, so neither a resolving name
    /// nor a peer starting to record can change its geometry.
    private var capsule: some View {
        VStack(spacing: Metrics.lineSpacing) {
            HStack(spacing: Metrics.spacing) {
                if header.avatarURIs.isEmpty {
                    accessories.hidden()
                } else {
                    avatars
                }
                Text(header.title)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .truncationMode(header.titleIsIdentifier ? .middle : .tail)
                accessories
            }
            Text(model.statusLine)
                .font(.subheadline.monospacedDigit())
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(1)
        }
        .padding(.horizontal, Metrics.horizontalPadding)
        .padding(.vertical, Metrics.verticalPadding)
        .frame(minHeight: Metrics.minimumHeight)
        .background(Color.black.opacity(0.35))
        .clipShape(Capsule())
        .contentShape(Capsule())
        .onTapGesture {
            if header.showsRoster { model.showsParticipants = true }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(header.showsRoster ? .isButton : [])
        .accessibilityHint(header.showsRoster
                            ? L10n.Accessibility.Conference.showParticipants : "")
    }

    /// The recording dot keeps its slot whether or not it shows, so a peer starting to
    /// record cannot widen the capsule. Avatars balance it when there are any; when
    /// there are none, a hidden copy does — mirroring the real thing rather than a
    /// hand-copied width, so adding an accessory can't silently un-centre the title.
    private var accessories: some View {
        HStack(spacing: Metrics.spacing) {
            recordingIndicator
            if header.showsRoster {
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.white.opacity(0.7))
                    .accessibilityHidden(true)
            }
        }
    }

    @ViewBuilder private var avatars: some View {
        if !header.avatarURIs.isEmpty {
            HStack(spacing: Metrics.avatarOverlap) {
                ForEach(Array(header.avatarURIs.enumerated()), id: \.element) { index, uri in
                    AvatarSwiftUIView(source: model.avatarProvider(forUri: uri),
                                      sizeOverride: Metrics.avatar)
                        .overlay(Circle().strokeBorder(Color.black.opacity(0.5),
                                                       lineWidth: Metrics.avatarBorder))
                        .zIndex(-Double(index))
                }
            }
            .accessibilityHidden(true)
        }
    }

    /// Always occupies its slot so that starting a recording cannot widen the capsule.
    private var recordingIndicator: some View {
        Circle()
            .fill(Color.red)
            .frame(width: Metrics.recordingDot, height: Metrics.recordingDot)
            .opacity(header.isRecording ? 1 : 0)
            .accessibilityHidden(!header.isRecording)
            .accessibilityLabel(L10n.Calls.peerRecording)
    }
}
