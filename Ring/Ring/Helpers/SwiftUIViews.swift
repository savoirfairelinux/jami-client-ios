/*
 *  Copyright (C) 2023 Savoir-faire Linux Inc.
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

let screenWidth = UIScreen.main.bounds.size.width
let screenHeight = UIScreen.main.bounds.size.height

enum IndicatorOrientation {
    case vertical
    case horizontal
}

struct Indicator: View {
    let orientation: IndicatorOrientation

    var body: some View {
        switch orientation {
        case .vertical:
            RoundedRectangle(cornerRadius: 5)
                .fill(Color(UIColor.lightGray))
                .frame(width: 5, height: 60)
        case .horizontal:
            RoundedRectangle(cornerRadius: 5)
                .fill(Color(UIColor.lightGray))
                .frame(width: 60, height: 5)
        }
    }
}

struct SizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

struct MeasureSizeModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(GeometryReader { geometry in
                Color.clear.preference(key: SizePreferenceKey.self, value: geometry.size)
            })
    }
}

struct UITextViewWrapper: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    @Binding var dynamicHeight: CGFloat
    let maxHeight: CGFloat = 100

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isScrollEnabled = true
        textView.textAlignment = .left
        textView.font = UIFont
            .systemFont(ofSize: UIFont.preferredFont(forTextStyle: .callout).pointSize)
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        textView.backgroundColor = UIColor.secondarySystemBackground
        textView.layer.cornerRadius = 18
        textView.clipsToBounds = true
        textView.delegate = context.coordinator
        return textView
    }

    func updateUIView(_ uiView: UITextView, context _: Context) {
        uiView.text = text

        DispatchQueue.main.async {
            if self.isFocused && !uiView.isFirstResponder {
                uiView.becomeFirstResponder()
            }
            dynamicHeight = min(
                uiView.sizeThatFits(CGSize(width: uiView.frame.size.width, height: .infinity))
                    .height,
                maxHeight
            )
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: UITextViewWrapper

        init(_ textViewWrapper: UITextViewWrapper) {
            parent = textViewWrapper
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }
    }
}
