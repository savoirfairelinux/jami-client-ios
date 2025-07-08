/*
 *  Copyright (C) 2023-2025 Savoir-faire Linux Inc.
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

struct Page: Equatable {
    let columns: Int
    let rows: Int
    let width: CGFloat
    let height: CGFloat
    let padding: CGFloat = 10

    init(columns: Int, rows: Int) {
        self.columns = columns
        self.rows = rows
        let marginVertical: CGFloat = CGFloat(rows + 1) * padding
        let marginHorizontal: CGFloat = CGFloat(columns - 1) * padding
        self.width = (ScreenDimensionsManager.shared.adaptiveWidth - marginHorizontal) / CGFloat(columns)
        self.height = (ScreenDimensionsManager.shared.adaptiveHeight - marginVertical) / CGFloat(rows)
    }
}

class MainGridViewModel: ObservableObject {
    @Published var pages = [Page]()
    @Published var firstParticipant: String = ""

    var count: Int = 0
    private let dimensionsManager = ScreenDimensionsManager.shared

    var maxColumn: CGFloat {
        return ScreenDimensionsManager.shared.isLandscape ? 4 : 3
    }

    var maxRows: CGFloat {
        return ScreenDimensionsManager.shared.isLandscape ? 3 : 4
    }

    init () {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(dimensionsDidChange),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func getPageLayoutForSinglePage(itemCount: Int) -> Page {
        var columns: Int = Int(CGFloat(itemCount) / maxRows) + 1
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
            var pages = Array(repeating: Page(columns: Int(maxColumn), rows: Int(maxRows)), count: numberOfFullLayouts)
            let addedElements: CGFloat = CGFloat(numberOfFullLayouts) * maxCellsPerLayout
            let remaining = CGFloat(itemCount) - addedElements

            if remaining > 0 {
                let numberOfRemainingLayouts = Int(ceil(remaining / minCellsPerLayout))
                pages.append(contentsOf: Array(repeating: Page(columns: Int(maxColumn), rows: (Int(maxRows) - 1)), count: numberOfRemainingLayouts))
            }
            return pages
        } else {
            let numberOfLayouts = Int(ceil(CGFloat(itemCount) / minCellsPerLayout))
            return Array(repeating: Page(columns: Int(maxColumn), rows: (Int(maxRows) - 1)), count: numberOfLayouts)
        }
    }

    func isFirstPage(index: Int) -> Bool {
        guard let firstPage = self.pages.first else { return true }
        let itemsCount = firstPage.columns * firstPage.rows
        return index < itemsCount
    }

    func updatedLayout(participantsCount: Int, firstParticipant: String) {
        if self.count != participantsCount {
            self.count = participantsCount
            self.pages = getPages(itemCount: participantsCount)
        }
        self.firstParticipant = firstParticipant
    }

    @objc
    private func dimensionsDidChange() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.pages = self.getPages(itemCount: self.count)
        }
    }
}
