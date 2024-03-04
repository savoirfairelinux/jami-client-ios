//
//  ReactionStickerView.swift
//  Ring
//
//  Created by Kessler DuPont on 2024-03-04.
//  Copyright © 2024 Savoir-faire Linux. All rights reserved.
//

import SwiftUI

struct ExpandableReactionOverlayView: View {
    
    @SwiftUI.State var currentDisplayValue: String
    @SwiftUI.State var backgroundColor: Color
    @SwiftUI.State private var reactions: [String] = [""]
    
    let items = Array(1...60)
    let columns = [
        GridItem(.adaptive(minimum: 100))
    ]
    
    var gridview: some View {
            GeometryReader { geometry in
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(items, id: \.self) { item in
                            // Your child view here
                            Text("\(item)")
                                .frame(width: geometry.size.width / CGFloat(columns.count) - 15,
                                       height: 50)
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                    }
                    .padding()
                }
            }
        }
    
    var body: some View {
        let tmpReactions: [String] = []//["👍", "👍", "👍", "👍", "👍"]
//        var reactions: [String] = [""]
//        if #available(iOS 16.0, *) {
////            reactions = currentDisplayValue.split(separator: "", omittingEmptySubsequences: true).map({ elem in
////                String(from: "\(elem)" as! Decoder)
////            })
//            self.reactions = currentDisplayValue.map({ String($0) })
//        } else {
//            self.reactions = ["ios 16 required"] // Fallback on earlier versions
//        }
//        ForEach(currentDisplayValue.indices, id: \.self) { index in

        
        
        gridview
        
        
        
        ForEach(tmpReactions.indices, id: \.self) { index in
            EmojiRowItemView(
//                cxModel: cxModel
                emoji: tmpReactions[index],
//                emoji: reactions[index],
//                emoji: String(currentDisplayValue.index(currentDisplayValue.startIndex, offsetBy: index)),
//                elementOpacity: 1.0 as CGFloat,
                delayIn: min(2.0, 0.03 * Double(index)),
                elementRotation: Angle(degrees: 45)
            )
        }
        Text(currentDisplayValue)
            .font(.callout)
            .fontWeight(.regular)
            .lineLimit(nil)
            .lineSpacing(5)
            .padding(5)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(10)
            .overlay(
             RoundedRectangle(cornerRadius: 10)
                 .stroke(backgroundColor, lineWidth: 0.8)
            )
            .padding(.trailing, 10)
            .padding(.leading, 30)
            .shadowForConversation()
            .measureSize()
            .onLongPressGesture(minimumDuration: 0.5) {
//            self.reactionsViewExpanded = true
//            print("KESS: expanded? = \(self.reactionsViewExpanded)")
            print("KESS: reactionsview long gesture")
            }
            .onAppear {
            print("KESS: appeared with content = \(currentDisplayValue)")
            }
    }
}

struct EmojiRowItemView: View {
//    var cxModel: ContextMenuVM
    var emoji: String
//    @Binding var presentingState: ContextMenuPresentingState
//    @SwiftUI.State var elementOpacity: CGFloat
    @SwiftUI.State var delayIn: Double
    @SwiftUI.State var elementRotation: Angle
    @SwiftUI.State private var enabledNotifierLength: CGFloat = 0

    var body: some View {
        let emojiActive = false// cxModel.localUserAuthoredReaction(emoji: emoji)
        VStack {
            Text(verbatim: emoji)
                .font(.title2)
//                .opacity(elementOpacity)
                .rotationEffect(elementRotation)
                .padding(.horizontal, 8)
                .padding(.vertical, 1)
                .overlay(
                    Rectangle()
                        .fill(Color(UIColor.defaultSwarm /*cxModel.presentingMessage.model.preferencesColor*/))
//                        .opacity(emojiActive ? elementOpacity : 0)
                        .frame(width: enabledNotifierLength, height: 2.5, alignment: .center)
                        .cornerRadius(8)
                        .offset(y: 18)
                        .onAppear(perform: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.3, blendDuration: 0.9).delay(delayIn + 0.5)) {
                                enabledNotifierLength = 20
                            }
                        })
                )
        }
//        .simultaneousGesture(
//            // handles adding or removing the reaction from the ReactionRow for the displayed message
//            TapGesture().onEnded({ _ in
////                cxModel.selectedEmoji = emoji
//            }))
        .onAppear {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6, blendDuration: 0.2).delay(delayIn)) {
//                elementOpacity = 1
            }
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6, blendDuration: 0.3).delay(delayIn)) {
                elementRotation = Angle(degrees: elementRotation.degrees / -2)
            }
            withAnimation(.spring(response: 0.2, dampingFraction: 0.3, blendDuration: 0.5).delay(delayIn + 0.3)) {
                elementRotation = Angle(degrees: 0)
            }
        }
    }

}

/*
 struct ExpandableReactionOverlayView: View {
 
 @SwiftUI.State var currentDisplayValue: String
 // TODO add the reaction data for creating revoke buttons like in EmojiPalette
 //@SwiftUI.State private var reactionData: [ReactionsRowViewModel]
 
 //    let messageModel: MessageContainerModel
 //    @SwiftUI.State var reactionsModel: ReactionsContainerModel
 //    @SwiftUI.StateObject var msgModel: MessageContentVM
 //    @SwiftUI.State private var reactionsViewExpanded: Bool = false
 
 var body: some View {
 // TODO ForEach in reactionsModel.displayValue
 Text(currentDisplayValue)
 .font(.callout)
 .fontWeight(.regular)
 .lineLimit(nil)
 .lineSpacing(5)
 .padding(5)
 .background(Color(UIColor.systemBackground))
 .cornerRadius(10)
 //            .overlay(
 //                RoundedRectangle(cornerRadius: 10)
 //                    .stroke(msgModel.backgroundColor, lineWidth: 0.8)
 //            )
 .padding(.trailing, 10)
 .padding(.leading, 30)
 .shadowForConversation()
 .measureSize()
 .onLongPressGesture(minimumDuration: 0.5) {
 self.reactionsViewExpanded = true
 print("KESS: expanded? = \(self.reactionsViewExpanded)")
 }
 .onAppear {
 print("KESS: appeared with content = \(currentDisplayValue)")
 }
 .padding(.bottom, 2)
 .onChange(of: currentDisplayValue, perform: {
 print("KESS: TODO animate from old state to new state")
 })
 //            .onChange(of: reactionsModel.displayValue, perform: {
 //                print("KESS: TODO animate from old state to new state")
 //            })
 }
 }
 // */
