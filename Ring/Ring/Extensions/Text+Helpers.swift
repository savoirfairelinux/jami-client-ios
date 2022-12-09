//
//  Text+Helpers.swift
//  Ring
//
//  Created by Binal Ahiya on 2023-01-10.
//  Copyright © 2023 Savoir-faire Linux. All rights reserved.
//

import SwiftUI

extension Text {
    func swarmButtonTextStyle() -> some View {
        self.frame(minWidth: 0, maxWidth: .infinity)
            .font(.system(size: 18))
            .padding()
            .foregroundColor(.white)
    }
}
