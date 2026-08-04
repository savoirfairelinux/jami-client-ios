import SwiftUI

extension View {
    func onVideoGlass<S: Shape>(_ shape: S, tint: Color = .jamiOnVideoGlass) -> some View {
        background(
            VisualEffect(style: .systemThinMaterialDark)
                .overlay(tint)
        )
        .clipShape(shape)
    }
}
