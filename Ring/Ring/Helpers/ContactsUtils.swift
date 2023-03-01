//
//  ContactUtils.swift
//  Ring
//
//  Created by kateryna on 2023-03-06.
//  Copyright © 2023 Savoir-faire Linux. All rights reserved.
//

import Foundation

class ContactsUtils {

    class func getFinalNameFrom(registeredName: String, profileName: String, hash: String) -> String {
        // priority: 1. profileName, 2. registeredName, 3. hash
        if registeredName.isEmpty && profileName.isEmpty {
            return hash
        }
        if !profileName.isEmpty {
            return profileName
        }
        return registeredName
    }

}
