/*
 *  Copyright (C) 2022 - 2025 Savoir-faire Linux Inc.
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
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
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
    @Environment(\.avatarProviderFactory)
    var avatarFactory: AvatarProviderFactory?
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let daySeparatorText = model.daySeparatorText {
                daySeparator(daySeparatorText)
            }
            Group {
                if model.centeredMessage {
                    centeredEvent()
                } else if model.incoming {
                    HStack(alignment: .messageBubbleBottom) {
                        if model.shouldDisplayAavatar,
                           let factory = avatarFactory {
                            Spacer()
                                .frame(width: 10)
                            let jamiId = messageModel.message.uri.isEmpty ? messageModel.message.authorId : messageModel.message.uri
                            AvatarSwiftUIView(source: factory.provider(for: jamiId, size: Constants.AvatarSize.conversation30))
                            Spacer()
                                .frame(width: 10)
                        } else {
                            Spacer()
                                .frame(width: model.leadingSpace)
                        }
                        MessageStackView(messageModel: messageModel, onLongPress: onLongPress, showReactionsView: showReactionsView)
                    }.padding(.trailing, 50)
                } else {
                    HStack(alignment: .messageBubbleBottom, spacing: 2) {
                        Spacer()
                        MessageStackView(messageModel: messageModel, onLongPress: onLongPress, showReactionsView: showReactionsView)
                        if model.showReciveIndicator {
                            Image("messageSentIndicator")
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
            }
            .padding(.top, model.topSpace)
            if let readIds = model.readIds, !readIds.isEmpty {
                HStack(alignment: .top, spacing: -3) {
                    Spacer()
                    ForEach(readIds.indices, id: \.self) { index in
                        if let factory = avatarFactory {
                            AvatarSwiftUIView(source: factory.provider(for: readIds[index],
                                                                       size: Constants.AvatarSize.conversation20))
                                .overlay(Circle().stroke(model.readBorderColor, lineWidth: 2))
                                .zIndex(Double(readIds.count - index))
                        }
                    }
                }
                .offset(x: 1)
                .padding(.top, Layout.readReceiptsSpacing)
                .accessibilityHidden(true)
            }
        }
        .padding(.bottom, model.bottomSpace)
        .padding(.horizontal, 5)
    }

    private func centeredEvent() -> some View {
        VStack(spacing: Layout.eventTimeSpacing) {
            // The rows drawn across the conversation rather than as a
            // bubble. Which one it is follows from the message; that it is
            // one of them at all is the flag's to say.
            Group {
                if let collabDoc = messageModel.collabDocViewModel {
                    HStack(spacing: 0) {
                        Spacer(minLength: Layout.centeredMessageMargin)
                        CollabDocMessageView(model: collabDoc)
                            .layoutPriority(1)
                        Spacer(minLength: Layout.centeredMessageMargin)
                    }
                } else {
                    ContactMessageView(model: messageModel.contactViewModel)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            if let eventGroupTimeText = model.eventGroupTimeText {
                MessageTimeView(text: eventGroupTimeText,
                                color: Color(UIColor.tertiaryLabel),
                                accessibilityText: model.eventGroupAccessibilityText)
            }
        }
    }

    private func daySeparator(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundColor(model.styling.secondaryTextColor)
            .padding(.horizontal, Layout.daySeparatorHorizontalPadding)
            .padding(.vertical, Layout.daySeparatorVerticalPadding)
            .background(Capsule().fill(Color(UIColor.tertiarySystemFill)))
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, Layout.daySeparatorOuterPadding)
            .accessibilityAddTraits(.isHeader)
    }

    private enum Layout {
        static let centeredMessageMargin: CGFloat = 30
        static let daySeparatorHorizontalPadding: CGFloat = 10
        static let daySeparatorVerticalPadding: CGFloat = 4
        static let daySeparatorOuterPadding: CGFloat = 10
        static let eventTimeSpacing: CGFloat = 6
        static let readReceiptsSpacing: CGFloat = 4
    }
}
