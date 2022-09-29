//
//  MessageRow.swift
//  Ring
//
//  Created by kateryna on 2022-09-26.
//  Copyright © 2022 Savoir-faire Linux. All rights reserved.
//

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

struct MessageRow: View {
    let messageModel: MessageViewModel
    @StateObject var model: MessageRowModel
    var body: some View {
        VStack(alignment: .leading) {
            if let time = model.timeString {
                Spacer()
                    .frame(height: 20)
                Text(time)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
                    .frame(height: 20)
            }
            if model.incoming {
                HStack(alignment: .bottom) {
                    if let avatar = model.avatarImage {
                        Image(uiImage: avatar)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 30, height: 30)
                            .cornerRadius(15)
                    } else {
                        Spacer()
                            .frame(width: 30)
                    }
                    Spacer()
                        .frame(width: 10)
                    MessageStackView(messageModel: messageModel)
                }.padding(.trailing, 50)
            } else {
                HStack(alignment: .bottom) {
                    Spacer()
                    MessageStackView(messageModel: messageModel)
                }.padding(.leading, 50)
            }
            if let readImages = model.read {
                Spacer()
                    .frame(height: 10)
                HStack(alignment: .top, spacing: -3) {
                    Spacer()
                    ForEach(0..<readImages.count, id: \.self) { index in
                        Image(uiImage: readImages[index])
                            .resizable()
                            .frame(width: 17, height: 17)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                            .zIndex(Double(readImages.count - index))
                    }
                }
                Spacer()
                    .frame(height: 10)
            }
        }.onAppear(perform: {
            model.fetchLastRead()
        })
        .padding(.top, -3)
        .padding(.bottom, -3)
        .padding(.leading, 15)
        .padding(.trailing, 15)
    }
}

struct MessageRow_Previews: PreviewProvider {
    // static var messageModels = ConversationViewController().messageViewModels
    static var previews: some View {
        MessageRow(messageModel: MessageViewModel(), model: MessageRowModel())
    }
}
