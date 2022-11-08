//
//  ContactListUI.swift
//  Ring
//
//  Created by Binal Ahiya on 2022-11-08.
//  Copyright © 2022 Savoir-faire Linux. All rights reserved.
//

import SwiftUI

struct ContactListUI: View {
    var body: some View {
        VStack {
            Text("Hello, SwiftUI!")
                .font(.largeTitle)
                .bold()
            Button("Getting Started") {
            }
        }
        .accentColor(Color.black)
        .background(Color.pink)
    }
}

struct ContactListUI_Previews: PreviewProvider {
    static var previews: some View {
        ContactListUI()
    }
}
