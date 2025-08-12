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

struct ContactMessageView: View {
    @StateObject var model: ContactMessageVM
    @Environment(\.avatarProviderFactory) var avatarFactory: AvatarProviderFactory?
    var body: some View {
        HStack(alignment: .center) {
            if model.needAvatar {
                if let factory = avatarFactory {
                    let jamiId = model.message.uri.isEmpty ? model.message.authorId : model.message.uri
                    AvatarSwiftUIView(source: factory.provider(for: jamiId, size: model.avatarSize, textSize: 8))
                        .frame(width: model.avatarSize, height: model.avatarSize)
                }
            }
            Spacer()
                .frame(width: model.inset)
            Text(model.content)
                .foregroundColor(model.styling.textColor)
                .lineLimit(1)
                .background(model.backgroundColor)
                .font(model.styling.textFont)
                .truncationMode(.middle)
        }
        .padding(.horizontal, model.inset)
        .frame(minHeight: model.height)
    }
}
