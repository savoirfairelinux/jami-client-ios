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

struct MessageStackView: View {
    let messageModel: MessageContainerModel
    var model: MessageStackVM {
        return messageModel.stackViewModel
    }
    var onLongPress: (_ frame: CGRect, _ message: MessageBubbleView) -> Void
    var showReactionsView: (_ message: ReactionsContainerModel?) -> Void
    var body: some View {
        VStack(alignment: model.horizontalAllignment) {
            if model.shouldDisplayName {
                Text(model.username)
                    .font(model.styling.secondaryFont)
                    .foregroundColor(model.styling.secondaryTextColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
                    .frame(height: 4)
            }
            MessageContentView(messageModel: messageModel,
                               model: messageModel.messageContent,
                               reactionsModel: messageModel.reactionsModel,
                               onLongPress: onLongPress,
                               showReactionsView: showReactionsView)
                .frame(maxWidth: .infinity, alignment: model.alignment)
        }
    }
}
