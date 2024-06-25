//
//  Array+Helper.swift
//  Ring
//
//  Created by kateryna on 2021-08-04.
//  Copyright © 2021 Savoir-faire Linux. All rights reserved.
//

import Foundation

extension Array where Element: Comparable {
    func isAscending() -> Bool {
        return zip(self, dropFirst()).allSatisfy(<=)
    }

    func isDescending() -> Bool {
        return zip(self, dropFirst()).allSatisfy(>=)
    }
}
