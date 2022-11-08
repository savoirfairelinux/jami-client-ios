//
//  ContactListUI.swift
//  Ring
//
//  Created by Binal Ahiya on 2022-11-08.
//  Copyright © 2022 Savoir-faire Linux. All rights reserved.
//

import SwiftUI
struct FriendList: Identifiable {
    var id: Int
    var imageName: ImageAsset
    var name: String
}
struct FriendListCell: View {
    var friend: FriendList
    var body: some View {
        HStack(alignment: .center, spacing: nil) {
            Label {
                Text(friend.name)
            }icon: {
                Image(uiImage: UIImage(asset: friend.imageName)!)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60, alignment: .center)
                    .clipShape(Circle())
            }
        }
    }
}
struct SwarmCreationUI: View {
    @SwiftUI.State private var users = [
        FriendList(id: 1, imageName: Asset.addAvatar, name: "Taylor Swift"),
        FriendList(id: 2, imageName: Asset.addAvatar, name: "Justin Bieber"),
        FriendList(id: 3, imageName: Asset.addAvatar, name: "Adele Adkins"),
        FriendList(id: 4, imageName: Asset.addAvatar, name: "Taylor Swift")
    ]
    let imageGroupIcon = UIImage(asset: Asset.addAvatar) as UIImage?

    var body: some View {
        VStack(alignment: .leading) {
            Label {
                Text("Hello, Binal")
                    .font(.custom("Ubuntu-Medium", size: 15))
                    .bold()
                    .frame(width: 100, height: 29)
                    .position(x: 80, y: 20)
            }icon: {
                Image(uiImage: imageGroupIcon!)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60, alignment: .center)
                    .clipShape(Circle())
            }
        }
        HStack(alignment: .center, spacing: nil) {
            List {
                ForEach(users) { user in
                    FriendListCell(friend: user)
                }
            }
            .listStyle(PlainListStyle())
            .frame(width: UIScreen.main.bounds.width, height: nil, alignment: .center)
            .accentColor(Color.black)
        }
    }
}

struct SwarmCreationUI_Previews: PreviewProvider {
    static var previews: some View {
        SwarmCreationUI().previewDevice("iPhone SE (2nd generation)")
    }
}
