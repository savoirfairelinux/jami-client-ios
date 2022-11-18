//
//  SwarmSettingsViewController.swift
//  Ring
//
//  Created by Alireza Toghiani on 11/4/22.
//  Copyright © 2022 Savoir-faire Linux. All rights reserved.
//

import SwiftUI

let sheetBackgroundColor: Color = Color(red: 245 / 256, green: 245 / 256, blue: 245 / 256)

struct SheetMenuView: View {

    var jamiID: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Spacer()

                Button {
                    // x button tap action
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .resizable()
                        .foregroundColor(.gray)
                        .frame(width: 28, height: 28)
                        .padding()
                }

            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Contact Jami")
                    .font(.system(.headline, design: .serif))
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                Text(jamiID)

            }
            .padding(.horizontal)

            VStack(alignment: .leading, spacing: 15) {
                SheetButton(action: {
                    // audio call button action
                }, labelText: "Audio call")

                SheetButton(action: {
                    // video call button action
                }, labelText: "Vidéo call")

                SheetButton(action: {
                    // message button action
                }, labelText: "Message")

                SheetButton(action: {
                    // administrator button action
                }, labelText: "Administrator")

                SheetButton(action: {
                    // delete button action
                }, labelText: "Delete from the swarm")

            }
            .padding(.vertical)
            .padding(.horizontal)

        }
        .background(sheetBackgroundColor)
        .clipShape(
            RoundedCorner(radius: 15, corners: [.topLeft, .topRight])
        )
    }
}

struct SheetButton: View {
    var action: () -> Void
    var labelText: String
    var body: some View {
        Button(action: action, label: {
            Text(labelText)
                .foregroundColor(.black)
        })
    }
}

struct RoundedCorner: Shape {

    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

struct SheetMenuView_Previews: PreviewProvider {
    static var previews: some View {
        SheetMenuView(jamiID: "097645678jhg876548765678909876987654")
            .previewLayout(.sizeThatFits)
    }
}
