//
//  ScreenHelper.swift
//  Ring
//
//  Created by Alireza Toghiani on 9/13/23.
//  Copyright © 2023 Savoir-faire Linux. All rights reserved.
//

import Foundation

class ScreenHelper {

    class func currentModalPresentationStyle() -> UIModalPresentationStyle {
        let screenSize = UIScreen.main.bounds.size
        return screenSize.width > screenSize.height ? .fullScreen : .formSheet
    }
}
