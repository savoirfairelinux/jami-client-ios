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

struct DefaultTransferView: View {
    @StateObject var model: MessageContentVM
    let onLongGesture: () -> Void
    var body: some View {
        HStack(alignment: .top) {
            HStack(alignment: .top) {
                Spacer()
                    .frame(width: 1)
                Image(systemName: "doc")
                    .resizable()
                    .foregroundColor(model.styling.textColor)
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                Spacer()
                    .frame(width: 10)
            }
            .highPriorityGesture(LongPressGesture(minimumDuration: 0.2)
                                    .onEnded { _ in
                                        onLongGesture()
                                    })
            VStack(alignment: .leading) {
                VStack(alignment: .leading) {
                    Text(model.fileName)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .font(model.styling.textFont)
                        .foregroundColor(model.styling.textColor)
                        .font(.headline)
                    Spacer()
                        .frame(height: 10)
                    Text(model.fileInfo)
                        .foregroundColor(model.styling.textColor)
                        .font(model.styling.secondaryFont)
                    if model.showProgress {
                        Spacer()
                            .frame(height: 15)
                        SwiftUI.ProgressView(value: model.fileProgress, total: 1)
                        Spacer()
                            .frame(height: 10)
                    }
                }
                .highPriorityGesture(LongPressGesture(minimumDuration: 0.2)
                                        .onEnded { _ in
                                            onLongGesture()
                                        })
                if !model.transferActions.isEmpty {
                    HStack {
                        ForEach(model.transferActions) { action in
                            Button(action.toString()) {
                                model.transferAction(action: action)
                            }
                            Spacer()
                                .frame(width: 20)
                        }
                    }
                }
            }
        }
        .padding(model.textInset)
        .background(model.backgroundColor)
    }
}
