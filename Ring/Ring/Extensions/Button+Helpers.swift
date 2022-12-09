//
//  Button+Helpers.swift
//  Ring
//
//  Created by Binal Ahiya on 2023-01-10.
//  Copyright © 2023 Savoir-faire Linux. All rights reserved.
//

import SwiftUI

extension Button {
    func swarmButtonStyle() -> some View {
        self.background(Color(UIColor.jamiButtonDark))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.all, 15.0)
    }
}
