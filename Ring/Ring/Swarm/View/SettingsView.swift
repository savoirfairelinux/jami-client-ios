//
//  SwarmSettingsViewController.swift
//  Ring
//
//  Created by Alireza Toghiani on 11/4/22.
//  Copyright © 2022 Savoir-faire Linux. All rights reserved.
//

import SwiftUI

struct SettingsView: View {

    @SwiftUI.State private var showGreeting = true
    @SwiftUI.State private var shouldShowColorPannel = false
    @AppStorage("SWARM_COLOR") var swarmColor = Color.blue
    var id: String!
    var swarmType: String!

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 21) {
                HStack {
                    Toggle("Ignore the swarm", isOn: $showGreeting)
                    //                        .tint(.teal)
                }

                Button(action: {
                    // ToDo: Call leave swarm action
                }, label: {
                    HStack {
                        Text("Leave the conversation")
                            .multilineTextAlignment(.leading)
                            .foregroundColor(.black)
                        Spacer()
                    }
                })

                ColorPicker("Choose a color", selection: $swarmColor)

                HStack {
                    Text("Type of swarm")
                    Spacer()
                    Text(swarmType)
                        .foregroundColor(.black)
                }

                HStack {
                    Text("Identifier")
                        .padding(.trailing, 30)
                    Spacer()
                    Text(id)
                        .foregroundColor(.black)
                        .multilineTextAlignment(.trailing)
                        .truncationMode(.tail)
                        .lineLimit(1)
                }

            }
            .padding(.horizontal, 15)
        }
        .padding()
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(id: "98239828928932899898298298329833", swarmType: "Others")
            .previewDevice(PreviewDevice(rawValue: "iPhone 12"))
            .previewDisplayName("iPhone 12")
    }
}
