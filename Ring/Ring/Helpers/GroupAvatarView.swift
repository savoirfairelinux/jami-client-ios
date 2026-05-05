/*
 *  Copyright (C) 2025 Savoir-faire Linux Inc.
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

        ZStack {
            if count == 1 {
                singleLayout(participant: participants[0], totalSize: totalSize)
            } else if count >= 2 {
                multiLayout(participants: participants, totalSize: totalSize)
            } else {
                emptyPlaceholder(totalSize: totalSize)
            }

            if provider.overflowCount > 0 {
                OverflowBadge(count: provider.overflowCount, size: totalSize * 0.38)
                    .offset(
                        x: totalSize * 0.32,
                        y: totalSize * 0.32
                    )
            }
        }
        .frame(width: totalSize, height: totalSize)
    }

    @ViewBuilder
    private func singleLayout(participant: ParticipantInfo, totalSize: CGFloat) -> some View {
        MiniAvatarView(source: participant.provider, size: totalSize)
    }

    @ViewBuilder
    private func multiLayout(participants: [ParticipantInfo], totalSize: CGFloat) -> some View {
        let miniSize = totalSize * 0.62
        let overlap = miniSize * 0.3
        let step = miniSize - overlap
        let visibleCount = CGFloat(participants.count)
        let totalWidth = miniSize + step * (visibleCount - 1)
        let startX = -totalWidth / 2 + miniSize / 2

        ForEach(Array(participants.enumerated().reversed()), id: \.element.jamiId) { index, participant in
            MiniAvatarView(source: participant.provider, size: miniSize)
                .overlay(
                    Circle()
                        .stroke(Color(UIColor.systemBackground), lineWidth: 2)
                )
                .offset(x: startX + step * CGFloat(index))
        }
    }

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
            let borderUIColor = bgColor.darker(by: 1) ?? bgColor
            let borderLineWidth = min(max(size * 0.04, 1), 1)
            Circle()
                .stroke(Color(borderUIColor), lineWidth: borderLineWidth)

            if !displayText.isSHA1() && !displayText.isEmpty {
                let factor: CGFloat = 0.44
                let raw = size * factor
                let fontSize = min(max(raw.rounded(), 8), 50)
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

struct OverflowBadge: View {
    let count: Int
    let size: CGFloat

    var body: some View {
        ZStack {
            Color(UIColor.systemGray)
            Text("+\(count)")
                .font(.system(size: size * 0.50, weight: .semibold))
                .foregroundColor(.white)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color(UIColor.systemBackground), lineWidth: 1.5)
        )
    }
}
