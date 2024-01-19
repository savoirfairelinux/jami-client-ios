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

import Foundation
import SwiftUI
import RxRelay

class ContextMenuVM {
    var sendEmoji = BehaviorRelay(value: [String: String]())
    var revokeEmoji = BehaviorRelay(value: [String: String]())
    @Published var menuItems = [ContextualMenuItem]()
    var presentingMessage: MessageBubbleView! {
        didSet {
            menuItems = presentingMessage.model.menuItems
            actionsAnchor = presentingMessage.model.message.incoming ? .topLeading : .topTrailing
            messsageAnchor = presentingMessage.model.message.incoming ? .bottomLeading : .bottomTrailing
            updateContextMenuSize()
            updateEmojiBarSize()
        }
    }
    var messageFrame: CGRect = CGRect.zero {
        didSet {
            updateSizes()
        }
    }

    var menuSize: CGSize = CGSize.zero {
        didSet {
            updateSizes()
        }
    }
    
    var emojiBarSize: CGSize = CGSize.zero {
        didSet {
            updateSizes()
        }
    }
    
    let itemHeight: CGFloat = 42
    let menuPadding: CGFloat = 15
    let minWidth: CGFloat = 220
    let menuImageSize: CGFloat = 18
    let menuItemFont = Font.callout
    let screenPadding: CGFloat = 100
    let menuCornerRadius: CGFloat = 3
//<<<<<<< HEAD
    let defaultVerticalPadding: CGFloat = 6
    let maxScaleFactor: CGFloat = 1.1
    var bottomOffset: CGFloat = 0 // move message up
//=======
    var finalBottomOffset: CGFloat = 0 // move message up
    var initialBottomOffset: CGFloat = 0 // move message up
    var finalBottomOffset: CGFloat = 0 // after accounting for actions bar space
//>>>>>>> c5d94aa1 ((WIP) iOS: emoji picker)
    var menuOffsetX: CGFloat = 0
    var menuOffsetY: CGFloat = 0
    var scaleMessageUp = true
    var actionsAnchor: UnitPoint = .center
    var messsageAnchor: UnitPoint = .center
    var messageHeight: CGFloat = 0
    var emojiVerticalPadding: CGFloat = 6
    var shadowColor: UIColor {
        return UITraitCollection.current.userInterfaceStyle == .light ? UIColor.tertiaryLabel : UIColor.black.withAlphaComponent(0.8)
    }

    func updateContextMenuSize() {
        let height: CGFloat = CGFloat(menuItems.count) * itemHeight + menuPadding * 2
        let fontAttributes = [NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .callout)]
        var width = minWidth
        for item in menuItems {
            let size = (item.toString() as NSString).size(withAttributes: fontAttributes)
            let newWidth: CGFloat = size.width + menuImageSize + menuPadding * 3
            if newWidth > width {
                width = newWidth
            }
        }
        let newHeight: CGFloat = min(height, UIScreen.main.bounds.height - screenPadding)
        let newWidth: CGFloat = min(width, UIScreen.main.bounds.width - screenPadding)
        menuSize = CGSize(width: newWidth, height: newHeight)
    }
    
    // TODO remove
    func updateEmojiBarSize() {
//        let fontAttributes = [NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .callout)]
//        let testEmoji: NSString = NSString(
//            string: String(
//                UnicodeScalar( UTF32Char(0x1F44D) )!
//            )
//        )
//        let padding = 6.0
//        let bb = testEmoji.size(withAttributes: fontAttributes)
        let gridSpace = CGSize(width: 42 + 8, height: 42 + 8)
//        let size =  + /*padding*/ 6
//        emojiBarSize = CGSize(width: 5.0 * (bb.width + padding) + padding, height: 1.0 * (bb.height + padding + padding))
        emojiBarSize = CGSize(width: 5.0 * gridSpace.width + 12, height: 1.0 * gridSpace.height)
//        print("bb = (\(bb.width), \(bb.height)) | width = \(emojiBarSize.width)")
    }
    
    func updateSizes() {
        if messageFrame == CGRect.zero || menuSize == CGSize.zero { return }
        let screenHeight = UIScreen.main.bounds.height
        let navBarHeight = UINavigationController.navBarHeight() + ( UIApplication.shared.windows.first?.windowScene?.statusBarManager?.statusBarFrame.height ?? 0)
        let messageOffsetY = messageFrame.origin.y
        let maxMessageHeight = screenHeight - (menuSize.height + navBarHeight + 80 + emojiBarSize.height)
        messageHeight = min(maxMessageHeight, messageFrame.height)
        let diff = screenHeight - (messageOffsetY + menuSize.height + navBarHeight + messageFrame.height)
        let diffOffset = max(0, messageFrame.height - messageHeight)
        bottomOffset = diff < 0 ? diff + diffOffset : 0
        if presentingMessage.messageModel.message.incoming {
            menuOffsetX = 0
        } else {
            menuOffsetX = messageFrame.width - menuSize.width
        }
        let difff = messageFrame.height + navBarHeight + menuSize.height - screenHeight
        scaleMessageUp = difff <= 0
        if scaleMessageUp {
            let heightDiff = messageHeight * maxScaleFactor - messageHeight
            /*
             Because the messageAnchor for the scale is at the bottom,
             the message will expand upwards. Therefore, it is necessary
             to add scaled space.
             */
            emojiVerticalPadding = defaultVerticalPadding + heightDiff
        }
        
        // handle message placement
        let bmp = messageHeight + emojiBarSize.height + menuSize.height + messageFrame.minY // bottomMostPointOnScreen
        if bmp < screenHeight - navBarHeight {
            // do nothing in regards to moving message into full view
            finalBottomOffset = initialBottomOffset
        } else {
            // move message up using finalBottomOffset
            finalBottomOffset =
        }
        
        initialBottomOffset = ([screenHeight, -messageOffsetY, -messageFrame.height / -2.0] as [CGFloat]).reduce(0, +)
        finalBottomOffset = 0
    }

//    func updateSizes() {
//        if messageFrame == CGRect.zero || menuSize == CGSize.zero { return }
//        let screenHeight = UIScreen.main.bounds.height
////        UIScreen.main.bounds.origin
//        let navBarHeight = UINavigationController.navBarHeight() + ( UIApplication.shared.windows.first?.windowScene?.statusBarManager?.statusBarFrame.height ?? 0)
//        let messageOffsetY = messageFrame.origin.y
//        let maxMessageHeight = screenHeight - (menuSize.height + navBarHeight + 80 - emojiBarSize.height)
//        messageHeight = min(maxMessageHeight, messageFrame.height)
////        let diffMid = screenHeight - (messageOffsetY + menuSize.height + navBarHeight + messageFrame.height + emojiBarSize.height)
//        print("KESS: ====")
//        print("KESS: mOff = \(messageOffsetY)")
//        let diffTop = ([screenHeight, messageOffsetY, navBarHeight, emojiBarSize.height] as [CGFloat]).reduce(0, +)
////        let diffTop = diffMid < 0 ? (screenHeight / 2.0) - diffMid : (screenHeight / 2.0) - diffMid
//        
//        
//        
//        
//        initialTopOffset = ([messageOffsetY, messageFrame.height / -2.0, -navBarHeight] as [CGFloat]).reduce(0, +)
////        //, messageHeight < screenHeight / 3.3 ? -emojiBarSize.height : 0] /// KESS
//        finalTopOffset = ([messageOffsetY, messageHeight / -2.0, -navBarHeight] as [CGFloat]).reduce(0, +)
////        print("KESS: itop = \(initialTopOffset)")
////        print("KESS: ftop = \(finalTopOffset)")
////        print("KESS: ====")
//        
//        
//        let diffOffset = max(0, messageFrame.height - messageHeight /*- emojiBarSize.height*/)
//        
//        ///
//        ///
//        ///
//        ///
//        
//                //        if diffMid < 0 {
//                //            // check for overflow bottom
//                //            if diffTop + menuSize.height > maxMessageHeight {
//                //                finalTopOffset = initialTopOffset - menuSize.height /// KESS
//                //            } else {
//                //                initialTopOffset = finalTopOffset
//                //            }
//                //            finalTopOffset -= navBarHeight + 80 - messageHeight < screenHeight / 3.3 ? emojiBarSize.height : 0
//                //            initialTopOffset -= navBarHeight + 80 - messageHeight < screenHeight / 3.3 ? emojiBarSize.height : 0
//                //
//                //            if diffTop + messageHeight + menuSize.height > maxMessageHeight {
//                //                let arr = [diffTop, -screenHeight, -navBarHeight, ] as [CGFloat]
//                //                finalBottomOffset = -(arr.reduce(0, +))
//                //            } else {
//                //                finalBottomOffset = 0
//                //            }
//                //        } else {
//                //            // check for overflow top
//                ////            if diffTop + menuSize.height > maxMessageHeight {
//                ////                finalTopOffset = initialTopOffset /// KESS
//                ////            } else {
//                ////                initialTopOffset = finalTopOffset
//                ////            }
//                ////            finalTopOffset -= navBarHeight + 80 - messageHeight < screenHeight / 3.3 ? emojiBarSize.height : 0
//                ////            initialTopOffset -= navBarHeight + 80 - messageHeight < screenHeight / 3.3 ? emojiBarSize.height : 0
//                //
//                //            if diffTop - emojiBarSize.height - messageHeight < navBarHeight {
//                //                let arr = [-diffTop, messageHeight, emojiBarSize.height] as [CGFloat]
//                //                finalBottomOffset = -(arr.reduce(0, +))
//                //            } else {
//                //                finalBottomOffset = 0
//                //            }
//                //        }
////        bottomOffset = diffMid < 0 ? diffMid + diffOffset : 0
////        print("KESS: top = \(diffTop) | screen = \(screenHeight) | boff = \(finalBottomOffset)")
//        ///
//        ///
//        ///
//        ///
//        
//        if presentingMessage.messageModel.message.incoming {
//            menuOffsetX = 0
//        } else {
//            menuOffsetX = messageFrame.width - menuSize.width
//        }
//        
//        let values = [messageFrame.height, emojiBarSize.height, navBarHeight, menuSize.height, -screenHeight] as [CGFloat]
//
//        let difff = values.reduce(0, +)
//
////        let difff = messageFrame.height + emojiBarSize + navBarHeight + menuSize.height - screenHeight
//        scaleMessageUp = difff <= 0
//        if scaleMessageUp {
//            let heightDiff = messageHeight * maxScaleFactor - messageHeight
//            /*
//             Because the messageAnchor for the scale is at the bottom,
//             the message will expand upwards. Therefore, it is necessary
//             to add scaled space.
//             */
//            emojiVerticalPadding = defaultVerticalPadding + heightDiff
//        }
//    }

    func sendEmoji(value: String, emojiActive: Bool) {
        if emojiActive {
            if let message = self.presentingMessage {
                // UNIMPLEMENTED TODO self.revokeEmoji.accept([message.model.message.id: value])
            }
        } else {
            if let message = self.presentingMessage {
                self.sendEmoji.accept([message.model.message.id: value])
            }
        }

    }

}
