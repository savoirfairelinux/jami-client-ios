//
//  MessagesList.swift
//  Ring
//
//  Created by kateryna on 2022-09-26.
//  Copyright © 2022 Savoir-faire Linux. All rights reserved.
//

import SwiftUI

struct MessagesList: View {
    @ObservedObject var list: MessagesListModel
    var body: some View {
        List {
            ForEach(list.messagesModels) { _ in
                MessageRow()
                // MessageRow(model: message)
            }
        }
    }
}

struct MessagesList_Previews: PreviewProvider {
    static var previews: some View {
        MessagesList(list: MessagesListModel())
    }
}
