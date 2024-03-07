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

//import CryptoKit
//func sha256Hash(for input: Date) -> String {
//    let inputData = Data("\(input.timeIntervalSince1970)".utf8)
//    let hashedData = SHA256.hash(data: inputData)
//    let hashString = hashedData.compactMap { String(format: "%02x", $0) }.joined()
//    return hashString
//}

struct ReactionRowView: View {
    
    var doButtons: Bool
    private let log = SwiftyBeaver.self
    var author: String
    var avatarImg: UIImage?
    var parentMsg: String?
    
    // @SwiftUI.ObservedObject var convoSizes: JamiSizesSingleton
    var reactions: [ReactionRowViewData]
    // @ObservedObject var reaction: ReactionsRowViewModel
    private let viewPadding: CGSize = CGSize(width: 12, height: 4) // TODO increase parent padding
    private let iconSize: CGSize = CGSize(width: 32, height: 32)
    // private let iconSize: CGSize = CGSize(width: 24, height: 24)
    
    private let reactionFontSize: CGFloat = 28
    private let columns = [GridItem(.adaptive(minimum: 32))]
    private let rowHeight: CGFloat = 48//2 * viewPadding.height + iconSize.height
    
    @SwiftUI.State private var currentGridSize: CGSize = CGSize(width: 16, height: 16)
    
    var reactionGridView: some View {
        GeometryReader { geometry in
//            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(reactions.indices, id: \.self) { index in
                            let reaction = reactions[index]
                            if doButtons {
                                Button(action: {
                                    log.debug("KESS: Tapped on reaction with value of \(reaction.textValue)")
                                }, label: {
                                    Text(reaction.textValue)
                                    .font(.system(size: reactionFontSize))
                                })
                                .frame(width: geometry.size.width / CGFloat(columns.count))
                            } else {
                                Text(reaction.textValue)
                                .font(.system(size: reactionFontSize))
                                .frame(width: geometry.size.width / CGFloat(columns.count))
                            }
                        }
                    }
                .onAppear(perform: {
                    currentGridSize = CGSize(width: 32, height: 58)
                    
                })
                .onChange(of: geometry.size, perform: { newSize in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
//                        let currentTime = Date()
//                        // Calculate hash
//                        let hash = sha256Hash(for: currentTime)
//                        let currentTimeHash = hash
                        print("KESS: updating geometry to \(newSize) \(Date().timeIntervalSince1970)")
                        currentGridSize = newSize
//                        currentGridSize.height = 140
                    }
//                    currentGridSize = geometry.size
                })
                .frame(width: 332 - (2.5 * iconSize.width), height: currentGridSize.height)
    //            .frame(minHeight: 2 * iconSize.height)
    //            .frame(maxHeight: UIScreen.main.bounds.size.width / 3)
                
                
//                } // ScrollView end
//            .frame(minHeight: 2 * iconSize.height)
            
            
//            .frame(minHeight: rowHeight * 1)//iconSize.height * 3)
//            .frame(maxHeight: UIScreen.main.bounds.size.width / 3)
//            .font(.title2)
//            .lineLimit(nil)
//            .multilineTextAlignment(.trailing)
//            .layoutPriority(0.5)
//            .padding(.horizontal, 2)
            
            
        } // GeometryReader end
    }
    
    @SwiftUI.State private var parentOffset: CGFloat = 0
    @SwiftUI.State private var childOffset: CGFloat = 0
    
    var splitView3: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
//                ScrollView(.vertical) {
//                    
//                }
                
                VStack(alignment: .center) {
                    // Content for left-side scroll view
                    if let img = avatarImg {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: iconSize.width, height: iconSize.height)
                            .cornerRadius(.infinity)
                    } else {
                        // Spacer().frame(width: viewPadding.width)
                        Spacer()
                    }
                    // TODO: Unify font sizes with singleton fontset
                    Text(author)
                        .font(.callout)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .layoutPriority(0.5)
                        .multilineTextAlignment(.leading)
                    if avatarImg == nil {
                        Spacer()
                    }
                    // END Content for left-side scroll view
                }
                .frame(width: 2.5 * iconSize.width)
                .offset(y: self.parentOffset)
                .gesture(DragGesture().onChanged { value in
                    // Update (left-side) parentOffset based on drag gesture
                    self.parentOffset = value.translation.height
                })
                .edgesIgnoringSafeArea(.all)

                ScrollView(.vertical) {
//                    VStack(alignment: .center) {
                        // Content for the right-side scroll view
//                        Spacer()
                        reactionGridView
                            .padding(20)
//                        Spacer()
                        // END Content for the right-side scroll view
//                    }
//                    .frame(minHeight: 32)
                    
//                    .frame(width: geometry.size.width / 2)
                    .background(Color.yellow)
                    .offset(y: self.childOffset)
                    .gesture(DragGesture().onChanged { value in
                        // Update (right-side) childOffset based on drag gesture
                        self.childOffset = value.translation.height
                    })
                }
                .edgesIgnoringSafeArea(.all)
            } // END HStack
        }
    }
    
    // /*
    var body: some View {
        splitView3
        .frame(height: currentGridSize.height)
//        .frame(minHeight: 1 * iconSize.height)
        .background(
            Color(.jamiFormBackground)
        )
        .cornerRadius(radius: 8, corners: .allCorners)
        .padding(12)
    }
    // */
}

func createReactionRowViewSplitViews() -> (some View, some View) {
    return (VStack{}, VStack{})
}

struct ReactionRowViewData {
    var msgId: String
    var textValue: String
    func hash(into hasher: inout Hasher) {
        hasher.combine(msgId)
    }
}

private func testEmoji(val: String) -> ReactionRowViewData {
    return ReactionRowViewData(msgId: val, textValue: val)
}

#Preview {
    
    ScrollView {
        VStack {
            
            Spacer()
            
            ReactionRowView(doButtons: true, author: "Kessler DuPont", parentMsg: nil, reactions: [
                testEmoji(val: "🍏"),
                testEmoji(val: "📗"),
                testEmoji(val: "💚")
            ])
//            .frame(height: 500)
            
            Spacer()
            
            ReactionRowView(doButtons: false, author: "Andreas", parentMsg: nil, reactions: [
                testEmoji(val: "🍊")
            ])
            
            Spacer()
            
            ReactionRowView(doButtons: false, author: "Megaman", parentMsg: nil, reactions: [
                testEmoji(val: "💜"),
                testEmoji(val: "😈"),
                testEmoji(val: "🟣"),
                testEmoji(val: "☂️"),
                testEmoji(val: "🍇"),
                testEmoji(val: "🎵"),
                testEmoji(val: "🌉"),
                testEmoji(val: "🦄"),
                testEmoji(val: "🟪"),
                testEmoji(val: "🍆")
            ])
            
            Spacer()
            
            ReactionRowView(doButtons: true, author: "Buttonguy", parentMsg: nil, reactions: [
                testEmoji(val: "💜"),
                testEmoji(val: "😈"),
                testEmoji(val: "🟣"),
                testEmoji(val: "☂️"),
                testEmoji(val: "🍇"),
                testEmoji(val: "🎵"),
                testEmoji(val: "🌉"),
                testEmoji(val: "🦄"),
                testEmoji(val: "🟪"),
                testEmoji(val: "🍆")
            ])
            
            Spacer()
            
            ReactionRowView(doButtons: true, author: "looong", parentMsg: nil, reactions: [
                testEmoji(val: "💙"),
                testEmoji(val: "🌀"),
                testEmoji(val: "🔵"),
                testEmoji(val: "🟦"),
                testEmoji(val: "💠"),
                testEmoji(val: "🦋"),
                testEmoji(val: "🐳"),
                testEmoji(val: "🧩"),
                testEmoji(val: "🚙"),
                testEmoji(val: "🔷"),
                testEmoji(val: "🌐"),
                testEmoji(val: "🦕"),
                testEmoji(val: "🎽"),
                testEmoji(val: "🎐"),
                testEmoji(val: "🧢"),
                testEmoji(val: "🦭"),
                testEmoji(val: "🎇"),
                testEmoji(val: "🐬"),
                testEmoji(val: "🔹"),
                testEmoji(val: "🛹"),
                testEmoji(val: "🏄‍♂️"),
                testEmoji(val: "📘"),
                testEmoji(val: "🚰"),
                testEmoji(val: "🦚"),
                testEmoji(val: "🚙"),
                testEmoji(val: "🌊"),
                testEmoji(val: "🚤"),
                testEmoji(val: "🧊")
            ])
            
            Spacer()
            
        }
    }
}
