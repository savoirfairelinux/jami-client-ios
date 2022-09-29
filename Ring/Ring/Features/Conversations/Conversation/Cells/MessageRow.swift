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
    let model: TestMessageModel
    // @ObservedObject var test = TestMessageModel()
    var body: some View {
        VStack {
            if let time = model.timeString {
                Text(time)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
                    .frame(height: 20)
            }
            if model.messageModel?.message.incoming ?? true {
                HStack(alignment: .bottom) {
                    if let aimage = model.avatarImage {
                        Image(uiImage: aimage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 30, height: 30)
                            .background(Color.blue)
                            .cornerRadius(15)
                    }
                    Spacer()
                        .frame(width: 10)
                    MessageStackView(model: model)
                }
            } else {
                HStack(alignment: .bottom) {
                    Spacer()
                    MessageStackView(model: model)
                    Spacer()
                        .frame(width: 10)
                    if let aimage = model.avatarImage {
                        Image(uiImage: aimage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 30, height: 30)
                            .background(Color.blue)
                            .cornerRadius(15)
                    }
                }
            }
            if let readImages = model.read {
                HStack(spacing: -3) {
                    Spacer()
                    ForEach(0..<readImages.count) { index in
                        Image(uiImage: readImages[index])
                            .resizable()
                            .frame(width: 15, height: 15)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.blue, lineWidth: 2))
                            .zIndex(Double(readImages.count - index))
                    }
                    Spacer()
                        .frame(width: 20)
                }
            }
        }
    }
}

struct MessageRow_Previews: PreviewProvider {
    // static var messageModels = ConversationViewController().messageViewModels
    static var previews: some View {
        MessageRow(model: TestMessageModel())
    }
}
