//
//  CollectionViewModel.swift
//  Ring
//
//  Created by kateryna on 2023-06-01.
//  Copyright © 2023 Savoir-faire Linux. All rights reserved.
//

import Foundation
import SwiftUI

class CollectionViewModel: ObservableObject {
    let maxRowNumber = 4
    @Published var gridItems = [GridItem(.flexible())]
    @Published var participants: [ParticipantViewModel]
    var layout: CallLayout
    var height: CGFloat = 0

    init(layout: CallLayout, participants: [ParticipantViewModel]) {
        self.layout = layout
        let filtered = participants.filter { participant in
            participant.info != nil
        }
        self.participants = filtered
        self.updateLayout()
    }

    func updateLayout() {
        if self.layout == .one {
            return
        }

        if self.layout == .oneWithSmal {
            self.createGridItem(number: 1, lastCentered: false)
            return
        }

        if self.participants.count < maxRowNumber {
            self.createGridItem(number: self.participants.count, lastCentered: false)
        }

        let lastCentered = self.participants.count % maxRowNumber != 0
        self.createGridItem(number: maxRowNumber, lastCentered: lastCentered)

    }

    func createGridItem(number: Int, lastCentered: Bool) {
        if number == 0 { return }
        gridItems = [GridItem]()
        height = UIScreen.main.bounds.height / CGFloat(number)
        for index in 1...number {
            if index == number - 1 {
                gridItems.append(GridItem(.fixed(100)))
            } else {
                gridItems.append(GridItem(.flexible()))
            }
        }

    }
}
