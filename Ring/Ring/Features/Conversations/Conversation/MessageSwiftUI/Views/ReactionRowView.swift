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

struct ReactionView: View {

    var reactionIn: String
    var doAnimations: Bool
    @SwiftUI.State private var fade: CGFloat = 0
    @SwiftUI.State private var currOffset: CGFloat = 8
    @SwiftUI.State var reactionFontSize: CGFloat = 0
    var callback: (() -> Void)?

    var body: some View {
        let factor: CGFloat = 0.5
        if let cbk = callback {
            Button(action: {
                cbk()
            }, label: {
                Text(reactionIn)
                    .font(.system(size: reactionFontSize))
            })            .opacity(fade)
            .offset(y: currOffset)
            .onAppear(perform: {
                if doAnimations {
                    currOffset = 8
                    withAnimation(.easeOut(duration: factor)) {
                        currOffset = 0
                        fade = 1
                    }
                }
            })
        } else {
            Text(reactionIn)
                .font(.system(size: reactionFontSize))
                .opacity(fade)
                .onAppear(perform: {
                    if doAnimations {
                        currOffset = 8
                        withAnimation(.easeOut(duration: factor)) {
                            currOffset = 0
                            fade = 1
                        }
                    }
                })
        }
    }
}

struct ReactionRowView: View {

    var doButtons: Bool
    private let log = SwiftyBeaver.self
    @ObservedObject var model: ReactionsRowVM

    // TODO: unified application font set
    // @SwiftUI.ObservedObject var convoSizes: JamiSizesSingleton
    private let viewPadding: CGSize = CGSize(width: 0, height: 0)
    private let innerViewPadding: CGSize = CGSize(width: 0, height: 0)
    private let iconSize: CGSize = CGSize(width: 32, height: 32)

    private let columns = [
        GridItem(.adaptive(minimum: 42))
    ] // influences number of columns for reactions

    @SwiftUI.State private var fade: CGFloat = 0
    // TODO make a helper function for this to restore previews!

    func reactionGridView() -> some View {
        let reactions: [ReactionRowViewData] = model.content.map({ key, value in ReactionRowViewData(msgId: key, textValue: value) })
        let stepSize = 3 // TODO can use this to make dynamic on rotation
        let indices = Array(stride(from: 0, to: reactions.count, by: stepSize)) // Use `to` instead of `through`

        return VStack(alignment: .center) {
            //            let useGridAlignment = reactions.count >= stepSize
            ForEach(indices, id: \.self) { baseIndex in
                HStack { // Create HStack to hold each row of reactions
                    ForEach(baseIndex..<min(baseIndex + stepSize, reactions.count), id: \.self) { index in
                        ReactionView(reactionIn: reactions[index].textValue, doAnimations: true, reactionFontSize: 28, callback: doButtons ? ({ /*print("access the text value like such \(reactions[index].textValue)") */ }) : nil)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 4)
                            .frame(width: 44, height: 44)
                    }
                }
            }
        }
    }

    func profileStack() -> some View {
        VStack(alignment: .leading) {
            Spacer()
            if let img = model.avatarImage {
                Button(action: {
                    // TODO can add a call here to show the user's profile card
                }, label: {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: iconSize.width, height: iconSize.height)
                        .cornerRadius(.infinity)
                })
            }
            // shows username next to reactions or the phrase "Me" if it is the current user
            if doButtons {
                Text(L10n.Account.me)
                    .font(.callout)
                    .lineLimit(1)
                    .truncationMode(.tail)
            } else {
                Text(model.username)
                    .font(.callout)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer()
        }
    }

    func splitView() -> some View {
        HStack {
            Spacer()
                .frame(width: 14)
            profileStack()
                .padding(.vertical, 14)
                .padding(.horizontal, 6)
            Spacer()
            reactionGridView()
                .padding(.vertical, 14)
                .padding(.horizontal, 6)
            Spacer()
                .frame(width: 14)

        }
    }

    var body: some View {
        splitView()
            .cornerRadius(radius: 8, corners: .allCorners)
            .padding(2)
    }
}

func createReactionRowViewSplitViews() -> (some View, some View) {
    return (VStack {}, VStack {})
}

struct ReactionRowViewData {
    var msgId: String
    var textValue: String

    func hash(into hasher: inout Hasher) {
        hasher.combine(msgId)
    }
}
