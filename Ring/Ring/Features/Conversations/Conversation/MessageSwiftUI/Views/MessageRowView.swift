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

// step 1 -- Create a shape view which can give shape
struct CornerRadiusShape: Shape {
    var radius = CGFloat.infinity
    var corners = UIRectCorner.allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

// step 2 - embed shape in viewModifier to help use with ease
struct CornerRadiusStyle: ViewModifier {
    var radius: CGFloat
    var corners: UIRectCorner

    func body(content: Content) -> some View {
        content
            .clipShape(CornerRadiusShape(radius: radius, corners: corners))
    }
}

// step 3 - crate a polymorphic view with same name as swiftUI's cornerRadius
extension View {
    func cornerRadius(radius: CGFloat, corners: UIRectCorner) -> some View {
        ModifiedContent(content: self, modifier: CornerRadiusStyle(radius: radius, corners: corners))
    }
}

extension View {
    /// Applies the given transform if the given condition evaluates to `true`.
    /// - Parameters:
    ///   - condition: The condition to evaluate.
    ///   - transform: The transform to apply to the source `View`.
    /// - Returns: Either the original `View` or the modified `View` if the condition is `true`.
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

struct MessageRowView: View {
    let messageModel: MessageContainerModel
    var onLongPress: (_ frame: CGRect, _ message: MessageBubbleView) -> Void
    var showReactionsView: (_ message: ReactionsContainerModel?) -> Void
    @ObservedObject var model: MessageRowVM
    var body: some View {
        VStack(alignment: .leading) {
            if model.shouldShowTimeString {
                Text(model.timeString)
                    .font(.caption)
                    .foregroundColor(model.styling.secondaryTextColor)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(10)
            }
            Spacer()
                .frame(height: model.topSpace)
            if model.centeredMessage {
                ContactMessageView(model: messageModel.contactViewModel)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if model.incoming {
                HStack(alignment: .bottom) {
                    if model.shouldDisplayAavatar {
                        Spacer()
                            .frame(width: 10)
//                        AvatarView(
//                            source: AvatarSourceAdapter(
//                                fromMessageAuthor: messageModel.stackViewModel.username,
//                                avatarData: nil,
//                                size: 30
//                            ),
//                            style: AvatarStyle(size: .s)
//                        )
                        .frame(width: 30, height: 30)
                        Spacer()
                            .frame(width: 10)
                    } else {
                        Spacer()
                            .frame(width: model.leadingSpace)
                    }
                    MessageStackView(messageModel: messageModel, onLongPress: onLongPress, showReactionsView: showReactionsView)
                }.padding(.trailing, 50)
            } else {
                HStack(alignment: .bottom, spacing: 2) {
                    Spacer()
                    MessageStackView(messageModel: messageModel, onLongPress: onLongPress, showReactionsView: showReactionsView)
                    if model.showReciveIndicator {
                        Image("message_sent_indicator")
                            .resizable()
                            .frame(width: 13, height: 13)
                    } else if model.showSentIndicator {
                        Circle()
                            .strokeBorder(Color.gray, lineWidth: 1)
                            .frame(width: 12, height: 12)
                    } else {
                        Spacer()
                            .frame(width: 13, height: 13)

                    }
                }.padding(.leading, 50)
            }
            if let readImages = model.read, !readImages.isEmpty {
                HStack(alignment: .top, spacing: -3) {
                    Spacer()
                    ForEach(0..<readImages.count, id: \.self) { index in
                        Image(uiImage: readImages[index])
                            .resizable()
                            .scaledToFill()
                            .frame(width: 20, height: 20)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(model.readBorderColor, lineWidth: 2))
                            .zIndex(Double(readImages.count - index))
                    }
                }
                .offset(x: 1)
            }
            Spacer()
                .frame(height: model.bottomSpace)
        }
        .padding(.top, 1)
        .padding(.bottom, 1)
        .padding(.leading, 5)
        .padding(.trailing, 5)
    }
}
