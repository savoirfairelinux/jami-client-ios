//
//  ContactListUI.swift
//  Ring
//
//  Created by Binal Ahiya on 2022-11-08.
//  Copyright © 2022 Savoir-faire Linux. All rights reserved.
//

import SwiftUI

struct ParticipantListCell: View {
    var participant: ParticipantList
    var body: some View {
        HStack(alignment: .center, spacing: nil) {
            Image(uiImage: UIImage(asset: participant.imageName)!)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 40, height: 40, alignment: .center)
                .clipShape(Circle())
            Text(participant.name)
                .font(.custom("Ubuntu", size: 13))
            Spacer()
        }
    }
}
struct SwarmCreationUI: View {
    @SwiftUI.State private var users = [
        ParticipantList(id: 1, imageName: Asset.addAvatar, name: "Taylor Swift"),
        ParticipantList(id: 2, imageName: Asset.addAvatar, name: "Justin Bieber"),
        ParticipantList(id: 3, imageName: Asset.addAvatar, name: "Adele Adkins"),
        ParticipantList(id: 4, imageName: Asset.addAvatar, name: "Taylor Swift"),
        ParticipantList(id: 5, imageName: Asset.addAvatar, name: "Taylor Swift"),
        ParticipantList(id: 6, imageName: Asset.addAvatar, name: "Justin Bieber"),
        ParticipantList(id: 7, imageName: Asset.addAvatar, name: "Adele Adkins"),
        ParticipantList(id: 8, imageName: Asset.addAvatar, name: "Taylor Swift")
    ]
    @SwiftUI.State private var swarmName: String = ""
    @SwiftUI.State private var swarmDescription: String = ""
    @SwiftUI.State private var searchParticipant: String = ""

    let imageGroupIcon = UIImage(asset: Asset.addAvatar) as UIImage?

    var body: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .center, spacing: 10) {
                Button(action: {
                    print("Hi! Binal")
                }) {
                    Image(uiImage: imageGroupIcon!)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60, alignment: .center)
                        .clipShape(Circle())
                        .padding(.leading, 20)
                }
                VStack {
                    TextField("Name", text: $swarmName)
                        .font(.custom("Ubuntu-Medium", size: 15))
                    TextField("Add description", text: $swarmDescription)
                        .font(.custom("Ubuntu-Medium", size: 14))
                }
                Spacer()
            }
        }
        List {
            ForEach(users) { user in
                ParticipantListCell(participant: user)
            }
        }
        .listStyle(PlainListStyle())
        .frame(width: UIScreen.main.bounds.width, height: nil, alignment: .leading)
        .accentColor(Color.black)
    }
}

struct SwarmCreationUI_Previews: PreviewProvider {
    static var previews: some View {
        SwarmCreationUI().previewDevice("iPhone SE (2nd generation)")
    }
}
