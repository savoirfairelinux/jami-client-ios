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

        print("****** view.bounds.width", screenSize.width)
        print("****** view.bounds.height", screenSize.height)
        print("****** view.bounds.width > view.bounds.height", screenSize.width > screenSize.height)
        if screenSize.width > screenSize.height {
            print("****** result .fullScreen")
        } else {
            print("****** result .formSheet")
        }
        return screenSize.width > screenSize.height ? .fullScreen : .formSheet
    }
}
