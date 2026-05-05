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
    @ObservedObject var provider: GroupAvatarProvider

    var body: some View {
        let totalSize = provider.totalSize
        let participants = provider.displayParticipants
        let count = participants.count
        let overflowCount = provider.overflowCount

        ZStack {
            if count == 1 && overflowCount == 0 {
                MiniAvatarView(source: participants[0].provider, size: totalSize)
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
        let border: CGFloat = max(totalSize * 0.035, 1.5)
        let hasThird = participants.count > 2 || overflowCount > 0

        let adminSize = totalSize * (hasThird ? 0.44 : 0.46)
        let otherSize = totalSize * (hasThird ? 0.34 : 0.36)

        let layout: [(x: CGFloat, y: CGFloat)] = hasThird
            ? [
                (x: totalSize * -0.06, y: totalSize * -0.14),
                (x: totalSize * 0.20, y: totalSize * 0.02),
                (x: totalSize * -0.08, y: totalSize * 0.20)
            ]
            : [
                (x: totalSize * -0.10, y: totalSize * -0.12),
                (x: totalSize * 0.14, y: totalSize * 0.16)
            ]

        ZStack {
            Circle().fill(Color(UIColor.systemGray5))

            if hasThird {
                if overflowCount > 0 {
                    OverflowBadge(count: overflowCount, size: otherSize)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color(UIColor.systemGray5), lineWidth: border))
                        .offset(x: layout[2].x, y: layout[2].y)
                } else if participants.count > 2 {
                    borderedMini(provider: participants[2].provider, size: otherSize, border: border)
                        .offset(x: layout[2].x, y: layout[2].y)
                }
            }

            if participants.count > 1 {
                borderedMini(provider: participants[1].provider, size: otherSize, border: border)
                    .offset(x: layout[1].x, y: layout[1].y)
            }

            borderedMini(provider: participants[0].provider, size: adminSize, border: border)
                .offset(x: layout[0].x, y: layout[0].y)
        }
        .clipShape(Circle())
    }

    private func borderedMini(provider: AvatarProvider, size: CGFloat, border: CGFloat) -> some View {
        MiniAvatarView(source: provider, size: size)
            .overlay(Circle().stroke(Color(UIColor.systemGray5), lineWidth: border))
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

// MARK: - Mini Avatar

struct MiniAvatarView: View {
    @ObservedObject var source: AvatarProvider
    let size: CGFloat

    var body: some View {
        ZStack {
            if let image = source.avatar {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.none)
                    .aspectRatio(contentMode: .fill)
            } else {
                monogramView
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    @ViewBuilder private var monogramView: some View {
        let displayText: String = !source.profileName.isEmpty
            ? source.profileName
            : (!source.registeredName.isEmpty ? source.registeredName : source.jamiId)

        let hex = displayText.toMD5HexString().prefixString()
        var idxValue: UInt64 = 0
        let colorIndex = Scanner(string: hex).scanHexInt64(&idxValue) ? Int(idxValue) : 0
        let bgColor = avatarColors[colorIndex]

        ZStack {
            Color(bgColor)

            if !displayText.isSHA1() && !displayText.isEmpty {
                let fontSize = min(max((size * 0.44).rounded(), 8), 50)
                Text(MonogramHelper.extractFirstGraphemeCluster(from: displayText))
                    .font(.system(size: fontSize, weight: .semibold))
                    .foregroundColor(.white)
            } else {
                let iconFontSize = max((size * 0.40).rounded(), 6)
                Image(systemName: "person.fill")
                    .font(.system(size: iconFontSize, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
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
