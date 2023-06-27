//
//  CollectionViewModel.swift
//  Ring
//
//  Created by kateryna on 2023-06-01.
//  Copyright © 2023 Savoir-faire Linux. All rights reserved.
//

import Foundation
import SwiftUI

struct Page {
    let columns: Int
    let rows: Int
    let width: CGFloat
    let height: CGFloat

    init(columns: Int, rows: Int) {
        self.columns = columns
        self.rows = rows
        self.width = UIScreen.main.bounds.width / CGFloat(columns)
        self.height = UIScreen.main.bounds.height / CGFloat(rows)
    }
}

class CollectionViewModel: ObservableObject {
    let maxRowNumber = 4
    @Published var gridItems = [GridItem(.flexible())]
    @Published var participants: [ParticipantViewModel]
    var layout: CallLayout
    var height: CGFloat = 100
    var pages = [Page]()
    var itemsPerColumn = 0
    var maxWidth: CGFloat = 100
    var maxColumn: CGFloat = 3
    let maxRows: CGFloat = 4
    var hasActive = false

    init(layout: CallLayout, participants: [ParticipantViewModel]) {
        self.layout = layout
        let filtered = participants.filter { participant in
            participant.info != nil
        }
        self.participants = filtered
        self.updateLayout()
    }

    func updateparticipants(participants: [ParticipantViewModel]) {
        let filtered = participants.filter { participant in
            participant.info != nil
        }
        self.participants = filtered
        print("\(self.participants.count) *********\(self.participants)")
        self.updateLayout()
    }

    func setLayout(layout: CallLayout) {
        self.layout = layout
        self.updateLayout()
    }

    func updateLayout() {
        self.pages = getPages()
    }

    func getLayoutForSinglePage() -> Page {
        let number: CGFloat = CGFloat(participants.count)
        var columns: Int = Int(number / maxRows) + 1
        if number == 8 {
            columns = 2
        }
        let rows = Int(ceil(number / CGFloat(columns)))
        return Page(columns: Int(columns), rows: rows)
    }

    func getPages() -> [Page] {
        let number: CGFloat = CGFloat(participants.count)
        if hasActive {
            let number13 = number > 4 ? 4 : number
            let number12 = Int(ceil(number / 4))
            return Array(repeating: Page(columns: Int(number13), rows: Int(1)), count: number12)
        }
        if number < 12 {
            return [getLayoutForSinglePage()]
        }
        let maxCells: CGFloat = maxColumn * maxRows
        let minCells = maxColumn * (maxRows - 1)
        let min: CGFloat = 0
        let max: CGFloat = 6
        var couldUseAllMax = true
        if number.truncatingRemainder(dividingBy: maxCells) > min && number.truncatingRemainder(dividingBy: maxCells) < max {
            couldUseAllMax = false
        }
        var couldUseAllMin = true
        if number.truncatingRemainder(dividingBy: minCells) > min && number.truncatingRemainder(dividingBy: minCells) < max {
            couldUseAllMin = false
        }

        if couldUseAllMax {
            let number1 = Int(ceil(number / maxCells))
            return Array(repeating: Page(columns: Int(maxColumn), rows: Int(maxRows)), count: number1)

        }

        if couldUseAllMin {
            let number1 = Int(ceil(number / minCells))
            return Array(repeating: Page(columns: Int(maxColumn), rows: (Int(maxRows) - 1)), count: number1)

        }

        var pages = [Page]()
        let number1 = Int(ceil(number / maxCells)) - 2
        if number1 > 0 {
            let addedElements: CGFloat = CGFloat(number1) * maxCells
            pages.append(contentsOf: Array(repeating: Page(columns: Int(maxColumn), rows: Int(maxRows)), count: number1))
            let remaining = number - addedElements
            if remaining == 0 {
                return pages
            }
            let number3 = Int(ceil(remaining / minCells))
            pages.append(contentsOf: Array(repeating: Page(columns: Int(maxColumn), rows: (Int(maxRows) - 1)), count: number3))
            return pages
        } else {
            let number1 = Int(ceil(number / minCells))
            return Array(repeating: Page(columns: Int(maxColumn), rows: (Int(maxRows) - 1)), count: number1)
        }
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
