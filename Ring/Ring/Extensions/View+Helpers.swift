/*
 *  Copyright (C) 2023 Savoir-faire Linux Inc.
 *
 *  Author: Binal Ahiya <binal.ahiya@savoirfairelinux.com>
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
import Combine

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .center,
        @ViewBuilder placeholder: () -> Content) -> some View {

        ZStack(alignment: alignment) {
            self

            if shouldShow {
                placeholder()
                    .allowsHitTesting(false)
            }
        }
    }

    func menuItemStyle() -> some View {
        self
            .frame(width: 22, height: 22)
            .foregroundColor(Color(UIColor.jamiButtonLight))
    }

    func measureSize() -> some View {
        self.modifier(MeasureSizeModifier())
    }

    func shadowForConversation() -> some View {
        self.shadow(color: Color(UIColor.quaternaryLabel), radius: 2, x: 1, y: 2)
    }

    public func border<S>(_ content: S, width: CGFloat = 1, cornerRadius: CGFloat) -> some View where S: ShapeStyle {
        let roundedRect = RoundedRectangle(cornerRadius: cornerRadius)
        return clipShape(roundedRect)
            .overlay(roundedRect.strokeBorder(content, lineWidth: width))
    }

    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    func conditionalModifier<T: ViewModifier>(_ modifier: T, apply: Bool) -> some View {
        Group {
            if apply {
                self.modifier(modifier)
            } else {
                self
            }
        }
    }

    func conditionalCornerRadius(_ radius: CGFloat, apply: Bool) -> some View {
        self.modifier(ConditionalCornerRadius(radius: radius, apply: apply))
    }

    func applyMessageStyle(model: MessageContentVM) -> some View {
        modifier(MessageTextStyle(model: model))
    }
}

extension Animation {
    static func dragableCaptureViewAnimation() -> Animation {
        return Animation.interpolatingSpring(stiffness: 100, damping: 20, initialVelocity: 0)
    }
}

struct ConditionalCornerRadius: ViewModifier {
    let radius: CGFloat
    let apply: Bool

    func body(content: Content) -> some View {
        if apply {
            content.cornerRadius(radius)
        } else {
            content
        }
    }
}

extension Publishers {
    static var keyboardHeight: AnyPublisher<CGFloat, Never> {
        let willShow = NotificationCenter.default.publisher(for: UIApplication.keyboardWillShowNotification)
            .map { $0.keyboardHeight }

        let willHide = NotificationCenter.default.publisher(for: UIApplication.keyboardWillHideNotification)
            .map { _ in CGFloat(0) }

        return MergeMany(willShow, willHide)
            .eraseToAnyPublisher()
    }
}

extension Notification {
    var keyboardHeight: CGFloat {
        (userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue.height ?? 0
    }
}
