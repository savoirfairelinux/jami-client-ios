/*
 *  Copyright (C) 2023-2024 Savoir-faire Linux Inc.
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
import SwiftyBeaver

struct ReactionsView: View {

    let log = SwiftyBeaver.self

    var currentJamiId: String
    @StateObject var model: ReactionsContainerModel
    @SwiftUI.State private var contentSize = CGSize(width: 300, height: 150)
    var closeCb: (() -> Void)
    let defaultSize: CGSize = CGSize(width: 300, height: 600)

    func makeReactionRows(numRows: Int) -> some View {
        let indiciesArr: Array<Int> = Array(0..<(numRows-1).advanced(by: 1))
        return VStack {
            // divider + given users reaction list
            ForEach(indiciesArr.indices, id: \.self) { indexIn in
                if indexIn != 0 {
                    Rectangle()
                        .fill(Color.gray)
                        .opacity(0.65)
                        .frame(width: 100, height: 0.75)
                }
                let rowIn = model.reactionsRow[indexIn]
                let doButtons = rowIn.jamiId == self.currentJamiId
                ReactionRowView(doButtons: doButtons, model: rowIn)
            }
        }
    }
    
    var content: some View {
        ScrollView {
            makeReactionRows(numRows: model.reactionsRow.count)
            .padding(.vertical)
            .padding(.horizontal, 4)
            .background(
                // this will dynamically adjust the height of reactionrowview fullscreen view in order to better show cases in which the number of users who have added reactions is greater than 1
                GeometryReader { proxy -> Color in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.easeOut(duration: 0.15)) {
                            self.contentSize = proxy.size
                        }
                    }
                    return Color.clear
                }
            )
        }
        .background(
            ZStack {
                Color(UIColor.systemBackground)
                    .opacity(1)
                VisualEffect(style: .regular, withVibrancy: true)
                    .opacity(1)
            }
        ) // TODO ZStack a gradient with swarm color on this
        .overlay(
            Button(action: {
                closeCb()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(Color(model.swarmColor))
            }
            .padding(6)
            .frame(width: contentSize.width, height: contentSize.height, alignment: .topTrailing)
            .opacity(0.75)
        )
        .cornerRadius(16)
        .shadowForConversation()
        .frame(maxWidth: contentSize.width, maxHeight: contentSize.height, alignment: .center)
    }

    var body: some View {
        ZStack(alignment: .center) {
            VisualEffect(style: .regular, withVibrancy: true)
                .opacity(0.15)
            Color(UIColor.systemBackground)
                .opacity(0.15)
            content
            ZStack(alignment: .topTrailing) {
            }
        }
    }
}
