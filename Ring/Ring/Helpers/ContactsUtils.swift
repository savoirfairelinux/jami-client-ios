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

    class func deserializeUser(dictionary: [String: String]) -> JamiSearchViewModel.JamsUserSearchModel? {
        guard let username = dictionary["username"], let firstName = dictionary["firstName"],
              let lastName = dictionary["lastName"], let organization = dictionary["organization"],
              let jamiId = dictionary["id"] ?? dictionary["jamiId"], let base64Encoded = dictionary["profilePicture"]
        else { return nil }

        return JamiSearchViewModel.JamsUserSearchModel(username: username, firstName: firstName,
                                                       lastName: lastName, organization: organization, jamiId: jamiId,
                                                       profilePicture: NSData(base64Encoded: base64Encoded,
                                                                              options: NSData.Base64DecodingOptions.ignoreUnknownCharacters) as Data?)
    }

}
