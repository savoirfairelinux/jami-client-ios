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

import XCTest
@testable import Ring

final class ContactUtilsTests: XCTestCase {

    func testGetFinalName_FromHashOnly() {
        let finalName = ContactsUtils.getFinalNameFrom(registeredName: "", profileName: "", hash: jamiId1)
        XCTAssertEqual(finalName, jamiId1)
    }

    func testGetFinalName_FromHashAndAlias() {
        let finalName = ContactsUtils.getFinalNameFrom(registeredName: "", profileName: profileName1, hash: jamiId1)
        XCTAssertEqual(finalName, profileName1)
    }

    func testGetFinalName_FromHashAndRegisteredName() {
        let finalName = ContactsUtils.getFinalNameFrom(registeredName: registeredName1, profileName: "", hash: jamiId1)
        XCTAssertEqual(finalName, registeredName1)
    }

    func testGetFinalName_FromHashAndRegisteredNameAndAlias() {
        let finalName = ContactsUtils.getFinalNameFrom(registeredName: registeredName1, profileName: profileName1, hash: jamiId1)
        XCTAssertEqual(finalName, profileName1)
    }

    func testDesirealizeuserDetails() {
        let userName = "username"
        let firstName = "firstName"
        let lastName = "lastName"
        let organization = "organization"
        let jamiId = "jamiId"
        let profilePicture = "profilePicture"
        let dictionary = ["username": userName,
                          "firstName": firstName,
                          "lastName": lastName,
                          "organization": organization,
                          "id": jamiId,
                          "profilePicture": profilePicture]
        let imageData = NSData(base64Encoded: profilePicture, options: NSData.Base64DecodingOptions.ignoreUnknownCharacters) as Data?
        let userDetails = ContactsUtils.deserializeUser(dictionary: dictionary)
        XCTAssertEqual(userDetails?.username, userName)
        XCTAssertEqual(userDetails?.firstName, firstName)
        XCTAssertEqual(userDetails?.lastName, lastName)
        XCTAssertEqual(userDetails?.organization, organization)
        XCTAssertEqual(userDetails?.jamiId, jamiId)
        XCTAssertEqual(userDetails?.profilePicture, imageData)
    }

}
