//
//  View+Helpers.swift
//  Ring
//
//  Created by Binal Ahiya on 2023-01-10.
//  Copyright © 2023 Savoir-faire Linux. All rights reserved.
//

import SwiftUI

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .center,
        @ViewBuilder placeholder: () -> Content) -> some View {

        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}
