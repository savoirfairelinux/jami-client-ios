//
//  ColorExtension.swift
//  Ring
//
//  Created by Alireza Toghiani on 11/14/22.
//  Copyright © 2022 Savoir-faire Linux. All rights reserved.
//
import SwiftUI

extension Color: RawRepresentable {

    public init?(rawValue: String) {

        guard let data = Data(base64Encoded: rawValue) else {
            self = .black
            return
        }

        do {
            let color = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? UIColor ?? .black
            self = Color(color)
        } catch {
            self = .black
        }

    }

    public var rawValue: String {

        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: UIColor(self), requiringSecureCoding: false) as Data
            return data.base64EncodedString()

        } catch {

            return ""

        }

    }

}
