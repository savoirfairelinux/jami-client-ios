/*
 *  Copyright (C) 2026 - 2026 Savoir-faire Linux Inc.
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

struct GroupAvatarView: View {
    @ObservedObject var source: AvatarProvider

    var body: some View {
        let totalSize = source.size.points
        let participants = source.displayParticipants
        let count = participants.count
        let overflowCount = source.overflowCount

        ZStack {
            if count == 1 && overflowCount == 0 {
                AvatarSwiftUIView(source: participants[0].provider, sizeOverride: totalSize)
            } else if count >= 2 {
                clusterView(
                    participants: participants,
                    overflowCount: overflowCount,
                    totalSize: totalSize
                )
            } else {
                emptyPlaceholder(totalSize: totalSize)
            }
        }
        .frame(width: totalSize, height: totalSize)
    }

    // MARK: - Cluster

    @ViewBuilder
    private func clusterView(
        participants: [ParticipantInfo],
        overflowCount: Int,
        totalSize: CGFloat
    ) -> some View {
        let hasThird = participants.count > 2 || overflowCount > 0

        let adminSize = totalSize * (hasThird ? 0.46 : 0.52)
        let otherSize = totalSize * (hasThird ? 0.30 : 0.34)

        let layout: [(x: CGFloat, y: CGFloat)] = hasThird
            ? [
                (x: totalSize * -0.14, y: totalSize * -0.16),
                (x: totalSize * 0.22, y: totalSize * 0.00),
                (x: totalSize * -0.04, y: totalSize * 0.24)
            ]
            : [
                (x: totalSize * -0.14, y: totalSize * -0.14),
                (x: totalSize * 0.18, y: totalSize * 0.18)
            ]

        let shadowRadius = totalSize * 0.03
        let shadowY = totalSize * 0.015

        ZStack {
            Circle().fill(Color(UIColor.systemGray6))

            if hasThird {
                if overflowCount > 0 {
                    OverflowBadge(count: overflowCount, size: otherSize)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.18), radius: shadowRadius, x: 0, y: shadowY)
                        .offset(x: layout[2].x, y: layout[2].y)
                } else if participants.count > 2 {
                    miniAvatar(provider: participants[2].provider, size: otherSize, shadowRadius: shadowRadius, shadowY: shadowY)
                        .offset(x: layout[2].x, y: layout[2].y)
                }
            }

            if participants.count > 1 {
                miniAvatar(provider: participants[1].provider, size: otherSize, shadowRadius: shadowRadius, shadowY: shadowY)
                    .offset(x: layout[1].x, y: layout[1].y)
            }

            miniAvatar(provider: participants[0].provider, size: adminSize, shadowRadius: shadowRadius, shadowY: shadowY)
                .offset(x: layout[0].x, y: layout[0].y)
        }
        .compositingGroup()
        .clipShape(Circle())
    }

    private func miniAvatar(provider: AvatarProvider, size: CGFloat, shadowRadius: CGFloat, shadowY: CGFloat) -> some View {
        AvatarSwiftUIView(source: provider, sizeOverride: size)
            .shadow(color: .black.opacity(0.18), radius: shadowRadius, x: 0, y: shadowY)
    }

    // MARK: - Empty

    @ViewBuilder
    private func emptyPlaceholder(totalSize: CGFloat) -> some View {
        let iconSize = max((totalSize * 0.40).rounded(), 6)
        ZStack {
            Color(avatarColors[0])
            Circle()
                .stroke(Color(avatarColors[0].darker(by: 1) ?? avatarColors[0]), lineWidth: 1)
            Image(systemName: "person.2.fill")
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundColor(.white)
        }
        .frame(width: totalSize, height: totalSize)
        .clipShape(Circle())
    }
}

// MARK: - Overflow Badge

struct OverflowBadge: View {
    let count: Int
    let size: CGFloat

    var body: some View {
        ZStack {
            Color(UIColor.systemGray3)
            Text("+\(count)")
                .font(.system(size: size * 0.44, weight: .semibold))
                .foregroundColor(.white)
        }
        .frame(width: size, height: size)
    }
}
