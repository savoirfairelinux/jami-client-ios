//
//  VideoInputDelegate.swift
//  Ring
//
//  Created by kateryna on 2023-05-18.
//  Copyright © 2023 Savoir-faire Linux. All rights reserved.
//

import Foundation

@objc protocol VideoInputDelegate {
    func writeFrame(withBuffer buffer: CVPixelBuffer?, forCallId: String)
}
