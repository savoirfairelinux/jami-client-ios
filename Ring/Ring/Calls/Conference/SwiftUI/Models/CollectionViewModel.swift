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
    var participants: [ParticipantViewModel] = []
    var layout: CallLayout = .grid {
        didSet {
            self.updateLayout()
        }
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
        gridItems = [GridItem]()
        for index in 1...number {
            if index == number - 1 {
                gridItems.append(GridItem(.fixed(100)))
            } else {
                gridItems.append(GridItem(.flexible()))
            }
        }

    }
}
