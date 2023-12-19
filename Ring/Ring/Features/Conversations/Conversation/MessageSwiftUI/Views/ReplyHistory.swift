/*
 *  Copyright (C) 2022 Savoir-faire Linux Inc.
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

struct ReplyHistory: View {
    let messageModel: MessageContainerModel
    var model: MessageHistoryVM {
        return messageModel.historyModel
    }
    var body: some View {
        VStack {
            HStack(alignment: .bottom) {
                VStack {
                    if let parent = model.replyTo {
                        Text(parent.content)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(EdgeInsets(top: 15, leading: 0, bottom: 15, trailing: 0))
                            .foregroundColor(.secondary)
                            .font(.body)

                    }
                    Spacer()
                        .frame(height: 5)
                    HStack(alignment: .bottom) {
                        Text(messageModel.messageContent.content)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(EdgeInsets(top: 15, leading: 0, bottom: 15, trailing: 0))
                            .foregroundColor(.secondary)
                            .font(.body)
                            .overlay(
                                CornerRadiusShape(radius: 15, corners: [.topLeft, .topRight, .bottomRight])
                                    .stroke(.gray, lineWidth: 2)
                            )
                    }
                }
            }
            .padding(EdgeInsets(top: 15, leading: 15, bottom: 5, trailing: 15))
            .padding(EdgeInsets(top: 0, leading: 0, bottom: 15, trailing: 0))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(.green, lineWidth: 2)
        )
        .padding()
    }
}
