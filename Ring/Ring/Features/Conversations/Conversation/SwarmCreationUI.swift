//
//  ContactListUI.swift
//  Ring
//
//  Created by Binal Ahiya on 2022-11-08.
//  Copyright © 2022 Savoir-faire Linux. All rights reserved.
//

import SwiftUI

struct SwarmCreationUI: View {
    var body: some View {
        VStack {
            Text("Hello, Binal")
                .font(.largeTitle)
                .bold()
            Button("Getting Started") {
            }
        }
        .accentColor(Color.black)
        .background(Color.pink)
    }
}

struct SwarmCreationUI_Previews: PreviewProvider {
    static var previews: some View {
        SwarmCreationUI().previewDevice("iPhone SE (2nd generation)")
    }
}
