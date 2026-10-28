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
    var onLongPress: (_ frame: CGRect, _ message: MessageBubbleView, _ mode: ContextMenuMode) -> Void
    @ObservedObject var model: MessageRowVM
    @Environment(\.avatarProviderFactory)
    var avatarFactory: AvatarProviderFactory?
    @Environment(\.messageListWidth)
    private var messageListWidth
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let daySeparatorText = model.daySeparatorText {
                daySeparator(daySeparatorText)
            }
            Group {
                if model.centeredMessage {
                    centeredEvent()
                } else {
                    bubbleRow()
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
                                .overlay(Circle().stroke(lineWidth: 2).blendMode(.destinationOut))
                                .zIndex(Double(readIds.count - index))
                        }
                    }
                }
                .compositingGroup()
                .offset(x: 1)
                .padding(.top, Layout.readReceiptsSpacing)
                .accessibilityHidden(true)
            }
        }
        .padding(.bottom, model.bottomSpace)
        .padding(.horizontal, Layout.rowHorizontalPadding)
    }

    private func bubbleRow() -> some View {
        HStack(alignment: .messageBubbleBottom, spacing: 0) {
            if model.incoming && model.reservesAvatarSlot {
                avatarSlot()
                    .padding(.horizontal, Layout.avatarHorizontalPadding)
            }
            MessageStackView(messageModel: messageModel, model: messageModel.stackViewModel, onLongPress: onLongPress)
                .environment(\.messageReactionsMaxWidth, reactionsMaxWidth)
            if !model.incoming {
                sentStatus()
                    .padding(.leading, Layout.sentStatusSpacing)
            }
        }
        .padding(.leading, bubbleRowLeadingInset)
        .padding(.trailing, model.incoming ? Layout.oppositeSideInset : 0)
    }

    private var bubbleRowLeadingInset: CGFloat {
        if !model.incoming {
            return Layout.oppositeSideInset
        }
        return model.reservesAvatarSlot ? 0 : Layout.oneToOneLeadingSpace
    }

    private var reactionsMaxWidth: CGFloat {
        guard messageListWidth > 0 else { return 0 }
        let anchoredSideInset: CGFloat
        if !model.incoming {
            anchoredSideInset = Layout.sentStatusSpacing + Layout.sentStatusSize
        } else if model.reservesAvatarSlot {
            anchoredSideInset = Constants.AvatarSize.conversation30.rawValue + 2 * Layout.avatarHorizontalPadding
        } else {
            anchoredSideInset = Layout.oneToOneLeadingSpace
        }
        return max(1, messageListWidth - 2 * Layout.rowHorizontalPadding - anchoredSideInset)
    }

    @ViewBuilder
    private func sentStatus() -> some View {
        if model.showReciveIndicator {
            Image("messageSentIndicator")
                .resizable()
                .frame(width: Layout.sentStatusSize, height: Layout.sentStatusSize)
        } else if model.showSentIndicator {
            Circle()
                .strokeBorder(Color.gray, lineWidth: 1)
                .frame(width: 12, height: 12)
        } else {
            Color.clear
                .frame(width: Layout.sentStatusSize, height: Layout.sentStatusSize)
        }
    }

    @ViewBuilder
    private func avatarSlot() -> some View {
        let size = Constants.AvatarSize.conversation30
        if model.shouldDisplayAavatar, let factory = avatarFactory {
            let jamiId = messageModel.message.uri.isEmpty ? messageModel.message.authorId : messageModel.message.uri
            AvatarSwiftUIView(source: factory.provider(for: jamiId, size: size))
        } else {
            Color.clear
                .frame(width: size.rawValue, height: size.rawValue)
        }
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
            .foregroundColor(.conversationSecondaryText)
            .padding(.horizontal, Layout.daySeparatorHorizontalPadding)
            .padding(.vertical, Layout.daySeparatorVerticalPadding)
            .conversationContentMaterial(tint: messageModel.messageContent.receivedBubbleColor, in: Capsule())
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, Layout.daySeparatorOuterPadding)
            .accessibilityAddTraits(.isHeader)
    }

    private enum Layout {
        static let oneToOneLeadingSpace: CGFloat = 12
        static let avatarHorizontalPadding: CGFloat = 10
        static let oppositeSideInset: CGFloat = 50
        static let sentStatusSpacing: CGFloat = 2
        static let sentStatusSize: CGFloat = 13
        static let rowHorizontalPadding: CGFloat = 5
        static let centeredMessageMargin: CGFloat = 30
        static let daySeparatorHorizontalPadding: CGFloat = 10
        static let daySeparatorVerticalPadding: CGFloat = 4
        static let daySeparatorOuterPadding: CGFloat = 10
        static let eventTimeSpacing: CGFloat = 6
        static let readReceiptsSpacing: CGFloat = 4
    }
}
