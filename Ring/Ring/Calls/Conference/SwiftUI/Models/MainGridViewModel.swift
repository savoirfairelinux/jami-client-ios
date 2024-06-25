/*
 *  Copyright (C) 2023 Savoir-faire Linux Inc.
 *
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA.
 */

import Foundation
import SwiftUI

var adaptiveScreenWidth: CGFloat {
    return UIDevice.current.orientation.isLandscape ? screenHeight : screenWidth
}

var adaptiveScreenHeight: CGFloat {
    return UIDevice.current.orientation.isLandscape ? screenWidth : screenHeight
}

struct Page: Equatable {
    let columns: Int
    let rows: Int
    let width: CGFloat
    let height: CGFloat
    let padding: CGFloat = 10

    init(columns: Int, rows: Int) {
        self.columns = columns
        self.rows = rows
        let marginVertical = CGFloat(rows + 1) * padding
        let marginHorizontal = CGFloat(columns - 1) * padding
        width = (adaptiveScreenWidth - marginHorizontal) / CGFloat(columns)
        height = (adaptiveScreenHeight - marginVertical) / CGFloat(rows)
    }
}

class MainGridViewModel: ObservableObject {
    @Published var pages = [Page]()
    @Published var firstParticipant: String = ""

    var count: Int = 0

    var maxColumn: CGFloat {
        return UIDevice.current.orientation.isLandscape ? 4 : 3
    }

    var maxRows: CGFloat {
        return UIDevice.current.orientation.isLandscape ? 3 : 4
    }

    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(rotated),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
    }

    func getPageLayoutForSinglePage(itemCount: Int) -> Page {
        var columns = Int(CGFloat(itemCount) / maxRows) + 1
        if columns == 0 {
            return Page(columns: 1, rows: 1)
        }
        if itemCount == 8 {
            columns = 2
        }
        let rows = Int(ceil(CGFloat(itemCount) / CGFloat(columns)))
        let page = Page(columns: Int(columns), rows: rows)
        return page
    }

    func getPages(itemCount: Int) -> [Page] {
        if itemCount < 12 {
            return [getPageLayoutForSinglePage(itemCount: itemCount)]
        }

        let maxCellsPerLayout: CGFloat = maxColumn * maxRows
        let minCellsPerLayout = maxColumn * (maxRows - 1)
        let numberOfFullLayouts = Int(ceil(CGFloat(itemCount) / maxCellsPerLayout)) - 2

        if minCellsPerLayout == 0 {
            return [Page(columns: 1, rows: 1)]
        }

        if numberOfFullLayouts > 0 {
            var pages = Array(
                repeating: Page(columns: Int(maxColumn), rows: Int(maxRows)),
                count: numberOfFullLayouts
            )
            let addedElements = CGFloat(numberOfFullLayouts) * maxCellsPerLayout
            let remaining = CGFloat(itemCount) - addedElements

            if remaining > 0 {
                let numberOfRemainingLayouts = Int(ceil(remaining / minCellsPerLayout))
                pages.append(contentsOf: Array(
                    repeating: Page(columns: Int(maxColumn), rows: Int(maxRows) - 1),
                    count: numberOfRemainingLayouts
                ))
            }
            return pages
        } else {
            let numberOfLayouts = Int(ceil(CGFloat(itemCount) / minCellsPerLayout))
            return Array(
                repeating: Page(columns: Int(maxColumn), rows: Int(maxRows) - 1),
                count: numberOfLayouts
            )
        }
    }

    func isFirstPage(index: Int) -> Bool {
        guard let firstPage = pages.first else { return true }
        let itemsCount = firstPage.columns * firstPage.rows
        return index < itemsCount
    }

    func updatedLayout(participantsCount: Int, firstParticipant: String) {
        if count != participantsCount {
            count = participantsCount
            pages = getPages(itemCount: participantsCount)
        }
        self.firstParticipant = firstParticipant
    }

    @objc
    func rotated() {
        pages = getPages(itemCount: count)
    }
}
