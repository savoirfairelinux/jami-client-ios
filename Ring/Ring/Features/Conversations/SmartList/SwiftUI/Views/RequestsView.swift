/*
 *  Copyright (C) 2024 Savoir-faire Linux Inc.
 *
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
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

import Foundation
import SwiftUI

struct RequestsIndicatorView: View {
    @ObservedObject var model: RequestsViewModel
    private let iconSize: CGFloat = 25
    private let cornerRadius: CGFloat = 12
    private let padding: CGFloat = 15
    private let badgePadding: CGFloat = 8
    private let badgeCornerRadius: CGFloat = 4
    private let verticalPaddingForBadge: CGFloat = 20
    private let horizontalPaddingForBody: CGFloat = 20
    private let verticalTextPadding: CGFloat = 5

    var body: some View {
        HStack(spacing: horizontalPaddingForBody) {
            icon
                .padding(.leading, horizontalPaddingForBody)
            description
            Spacer()
            unreadCounter
                .padding(.trailing, horizontalPaddingForBody)
        }
        .frame(maxWidth: .infinity)
        .background(Color.jamiPrimaryControl)
        .cornerRadius(cornerRadius)
    }

    private var icon: some View {
        Image(systemName: "envelope.badge")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: iconSize, height: iconSize)
            .foregroundColor(.white)
    }

    private var description: some View {
        VStack(alignment: .leading, spacing: verticalTextPadding) {
            Text(model.title)
                .bold()
                .lineLimit(1)
                .font(.footnote)
                .foregroundColor(.white)
            Text(model.requestNames)
                .lineLimit(1)
                .font(.footnote)
                .foregroundColor(.white)
        }
    }

    private var unreadCounter: some View {
        Text("\(model.unreadRequests)")
            .font(.footnote)
            .bold()
            .foregroundColor(.white)
            .padding(.all, badgePadding)
            .background(Color.jamiSecondaryControl)
            .clipShape(RoundedRectangle(cornerRadius: badgeCornerRadius))
            .padding(.vertical, verticalPaddingForBadge)
    }
}
