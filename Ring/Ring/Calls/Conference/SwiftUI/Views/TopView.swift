/*
 *  Copyright (C) 2023 Savoir-faire Linux Inc.
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

import SwiftUI

struct TopView: View {
    @Binding var participants: [ParticipantViewModel]
    let width: CGFloat = 150
    let height: CGFloat = 100
    var body: some View {
        VStack {
            Spacer()
                .frame(height: 30)
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(participants) { participant in
                        ParticipantView(model: participant, width: width, height: height)
                    }
                }
                .background(Color.black.frame(width: 99_999_999))
            }
        }
    }
}
