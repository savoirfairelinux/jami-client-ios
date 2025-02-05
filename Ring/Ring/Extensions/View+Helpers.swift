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

struct PlatformAdaptiveNavView<Content: View>: View {
    let content: () -> Content

    var body: some View {
        if #available(iOS 16.0, *) {
            NavigationStack {
                content()
            }
            .accentColor(.jamiColor)
        } else {
            NavigationView {
                content()
            }
            .accentColor(.jamiColor)
            .navigationViewStyle(StackNavigationViewStyle())
        }
    }
}

struct SlideTransition: ViewModifier {
    let directionUp: Bool

    func body(content: Content) -> some View {
        content
            .transition(.asymmetric(
                insertion: .move(edge: directionUp ? .bottom : .top),
                removal: .move(edge: directionUp ? .top : .bottom)
            ))
    }
}

extension View {
    func applySlideTransition(directionUp: Bool) -> some View {
        self.modifier(SlideTransition(directionUp: directionUp))
    }
}

struct RowSeparatorHiddenModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 15.0, *) {
            content
                .listRowSeparator(.hidden)
                .listRowSeparatorTint(.clear)
        } else {
            content
        }
    }
}

extension View {
    func hideRowSeparator() -> some View {
        self.modifier(RowSeparatorHiddenModifier())
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

struct TextSelectionModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 15.0, *) {
            content.textSelection(.enabled)
        } else {
            content
        }
    }
}

extension View {
    func conditionalTextSelection() -> some View {
        self.modifier(TextSelectionModifier())
    }
}

struct OptionalMediumPresentationDetents: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.presentationDetents([.medium])
        } else {
            content
        }
    }
}

extension View {
    func optionalMediumPresentationDetents() -> some View {
        self.modifier(OptionalMediumPresentationDetents())
    }
}

struct OptionalRowSeparator: ViewModifier {
    let hidden: Bool

    func body(content: Content) -> some View {
        if #available(iOS 15.0, *) {
            content
                .listRowSeparator(hidden ? .hidden : .visible)
        } else {
            content
        }
    }
}

extension View {
    func optionalRowSeparator(hidden: Bool) -> some View {
        self.modifier(OptionalRowSeparator(hidden: hidden))
    }
}

struct OptionalListSectionSpacing: ViewModifier {
    let spacing: CGFloat

    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content
                .listSectionSpacing(spacing)
        } else {
            content
        }
    }
}

extension View {
    func optionalListSectionSpacing(_ spacing: CGFloat) -> some View {
        self.modifier(OptionalListSectionSpacing(spacing: spacing))
    }
}

struct CloseButton: View {
    let action: () -> Void
    let accessibilityIdentifier: String
    
    var body: some View {
        Button(action: {
            action()
        }, label: {
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.black)
                .padding(10) // Increases tap area
                .background(Circle().fill(Color.gray.opacity(0.4)))
                .accessibilityIdentifier(accessibilityIdentifier)
                .accessibilityLabel(L10n.Accessibility.close)
                .padding()
        })
    }
}
