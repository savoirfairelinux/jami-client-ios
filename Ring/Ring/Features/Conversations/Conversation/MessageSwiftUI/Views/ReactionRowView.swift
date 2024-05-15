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
    let model: ReactionsRowViewModel

    // TODO: unified application font set
    // @SwiftUI.ObservedObject var convoSizes: JamiSizesSingleton
    private let viewPadding: CGSize = CGSize(width: 0, height: 0)
    private let innerViewPadding: CGSize = CGSize(width: 0, height: 0)
    private let iconSize: CGSize = CGSize(width: 32, height: 32)

    private let columns = [
        GridItem(.adaptive(minimum: 42))
    ] // influences number of columns for reactions

    @SwiftUI.State private var fade: CGFloat = 0
    @SwiftUI.State private var colWidth: CGFloat = 42
    @SwiftUI.State private var anims: [String: CGFloat] = [:]

    func reactionGridView() -> some View {
        let reactions: [ReactionRowViewData] = model.content.map({ key, value in ReactionRowViewData(msgId: key, textValue: value) })
        let stepSize = 3 // TODO can use this to make dynamic on rotation
        let indices = Array(stride(from: 0, to: reactions.count, by: stepSize)) // Use `to` instead of `through`

        return VStack(alignment: .center) {
            let useGridAlignment = reactions.count >= stepSize
            ForEach(indices, id: \.self) { baseIndex in
                HStack { // Create HStack to hold each row of reactions
                    ForEach(baseIndex..<min(baseIndex + stepSize, reactions.count), id: \.self) { index in
                        ReactionView(reactionIn: reactions[index].textValue, doAnimations: true, reactionFontSize: 28, callback: doButtons ? ({ /*print("access the text value like such \(reactions[index].textValue)") */}) : nil)
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
                    // TODO show profile card
                }, label: {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: iconSize.width, height: iconSize.height)
                        .cornerRadius(.infinity)
                })
            }
            // TODO: Unify font sizes with singleton fontset
            // shows username next to reactions & bold if current user
            let author = model.username
            if #available(iOS 16.0, *) {
                Text(author)
                    .font(.callout)
                    .lineLimit(1)
                    .bold(doButtons)
                    .truncationMode(.tail)
            } else {
                Text(author)
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
                .frame(width: 16)
            profileStack()
                .padding(.vertical, 16)
                .padding(.horizontal, 6)
            Spacer()
            reactionGridView()
                .padding(.vertical, 16)
                .padding(.horizontal, 6)
            Spacer()
                .frame(width: 16)

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

//// preview design code below
//
// private func testEmoji(val: String) -> ReactionRowViewData {
//    return ReactionRowViewData(msgId: val, textValue: val)
// }
//
// private struct TestView: View {
//
//    @SwiftUI.State private var isContentVisible = true
//
//    var body: some View {
//        VStack {
//            Button(action: {
//                isContentVisible.toggle()
//            }, label: {
//                Text("Toggle Content Visibility")
//                    .font(.system(size: 24))
//            })
//            if isContentVisible {
//                showTestViews()
//            }
//        }
//    }
// }
//
//// swiftlint:disable closure_body_length function_body_length
// private func showTestViews() -> some View {
//    ScrollView(.vertical) {
//        VStack {
//
//            Spacer()
//
//            ReactionRowView(doButtons: true, author: "123", parentMsg: nil, reactions: [
//                testEmoji(val: "🍏"),
//                testEmoji(val: "📗"),
//                testEmoji(val: "💚")
//            ])
//
//            Spacer()
//
//            ReactionRowView(doButtons: true, author: "Kessler DuPont", parentMsg: nil, reactions: [
//                testEmoji(val: "🍏"),
//                testEmoji(val: "📗"),
//                testEmoji(val: "💚")
//            ])
//
//            Spacer()
//
//            ReactionRowView(doButtons: false, author: "Andreas", parentMsg: nil, reactions: [
//                testEmoji(val: "🍊")
//            ])
//
//            Spacer()
//
//            ReactionRowView(doButtons: false, author: "Megaman", parentMsg: nil, reactions: [
//                testEmoji(val: "💜"),
//                testEmoji(val: "😈"),
//                testEmoji(val: "🟣"),
//                testEmoji(val: "☂️"),
//                testEmoji(val: "🍇"),
//                testEmoji(val: "🎵"),
//                testEmoji(val: "🌉"),
//                testEmoji(val: "🦄"),
//                testEmoji(val: "🟪"),
//                testEmoji(val: "🍆")
//            ])
//
//            Spacer()
//
//            ReactionRowView(doButtons: true, author: "Buttonguy", parentMsg: nil, reactions: [
//                testEmoji(val: "💜"),
//                testEmoji(val: "😈"),
//                testEmoji(val: "🟣"),
//                testEmoji(val: "☂️"),
//                testEmoji(val: "🍇"),
//                testEmoji(val: "🎵"),
//                testEmoji(val: "🌉"),
//                testEmoji(val: "🦄"),
//                testEmoji(val: "🟪"),
//                testEmoji(val: "🍆")
//            ])
//
//            Spacer()
//
//            ReactionRowView(doButtons: true, author: "looong", parentMsg: nil, reactions: [
//                testEmoji(val: "💙"),
//                testEmoji(val: "🌀"),
//                testEmoji(val: "🔵"),
//                testEmoji(val: "🟦"),
//                testEmoji(val: "💠"),
//                testEmoji(val: "🦋"),
//                testEmoji(val: "🐳"),
//                testEmoji(val: "🧩"),
//                testEmoji(val: "🚙"),
//                testEmoji(val: "🔷"),
//                testEmoji(val: "🌐"),
//                testEmoji(val: "🦕"),
//                testEmoji(val: "🎽"),
//                testEmoji(val: "🎐"),
//                testEmoji(val: "🧢"),
//                testEmoji(val: "🦭"),
//                testEmoji(val: "🎇"),
//                testEmoji(val: "🐬"),
//                testEmoji(val: "🔹"),
//                testEmoji(val: "🛹"),
//                testEmoji(val: "🏄‍♂️"),
//                testEmoji(val: "📘"),
//                testEmoji(val: "🚰"),
//                testEmoji(val: "🦚"),
//                testEmoji(val: "🚙"),
//                testEmoji(val: "🌊"),
//                testEmoji(val: "🚤"),
//                testEmoji(val: "🧊")
//            ])
//
//            ReactionRowView(doButtons: false, author: "2looong", parentMsg: nil, reactions: [
//                testEmoji(val: "💙"),
//                testEmoji(val: "🌀"),
//                testEmoji(val: "🔵"),
//                testEmoji(val: "🟦"),
//                testEmoji(val: "💠"),
//                testEmoji(val: "🦋"),
//                testEmoji(val: "🐳"),
//                testEmoji(val: "🧩"),
//                testEmoji(val: "🚙"),
//                testEmoji(val: "🔷"),
//                testEmoji(val: "🌐"),
//                testEmoji(val: "🦕"),
//                testEmoji(val: "🎽"),
//                testEmoji(val: "🎐"),
//                testEmoji(val: "🧢"),
//                testEmoji(val: "🦭"),
//                testEmoji(val: "🎇"),
//                testEmoji(val: "🐬"),
//                testEmoji(val: "🔹"),
//                testEmoji(val: "🛹"),
//                testEmoji(val: "🏄‍♂️"),
//                testEmoji(val: "📘"),
//                testEmoji(val: "🚰"),
//                testEmoji(val: "🦚"),
//                testEmoji(val: "🚙"),
//                testEmoji(val: "🌊"),
//                testEmoji(val: "🚤"),
//                testEmoji(val: "🧊")
//            ])
//
//            Spacer()
//
//        }
//    } // scroll view END
// }
//// swiftlint:enable closure_body_length function_body_length
//
// #Preview {
//
//    TestView()
//
// }
