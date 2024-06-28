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

final class VCardUtilsTests: XCTestCase {

    let photo = "photo.jpg"

    func generateVCardStingWithNameAndImage() -> String {
        return """
        BEGIN:VCARD
        FN:\(profileName1)
        TEL;other:ring:\(jamiId1)
        PHOTO;ENCODING=BASE64;TYPE=JPEG:\(photo)
        END:VCARD
        """
    }

    func generateVCardStingWithName() -> String {
        return """
        BEGIN:VCARD
        FN:\(profileName1)
        TEL;other:ring:\(jamiId1)
        END:VCARD
        """
    }

    func generateVCardStingWithImage() -> String {
        return """
        BEGIN:VCARD
        FN:
        TEL;other:ring:\(jamiId1)
        PHOTO;ENCODING=BASE64;TYPE=JPEG:\(photo)
        END:VCARD
        """
    }

    func getJamiUri() -> String {
        return "ring:\(jamiId1)"
    }

    func testParseToProfile() {
        // Arrange
        let data = generateVCardStingWithNameAndImage().data(using: .utf8)!
        // Act
        let profile = VCardUtils.parseDataToProfile(data: data)
        // Assert
        XCTAssertEqual(profile?.alias, profileName1)
        XCTAssertEqual(profile?.photo, photo)
        XCTAssertEqual(profile?.uri, getJamiUri())
    }

    func testDataWithImageAndUUID_whenProfileHasPhotoAndAlias() throws {
        // Arrange
        let profile = Profile(uri: getJamiUri(), alias: profileName1, photo: photo, type: ProfileType.ring.rawValue)
        let expectedData = generateVCardStingWithNameAndImage().data(using: .utf8)
        // Act
        let data = try XCTUnwrap(VCardUtils.dataWithImageAndUUID(from: profile))
        // Assert
        XCTAssertEqual(data, expectedData)
    }

    func testDataWithImageAndUUID_whenProfileMissingPhoto() throws {
        // Arrange
        let profile = Profile(uri: getJamiUri(), alias: profileName1, photo: nil, type: ProfileType.ring.rawValue)
        let expectedData = generateVCardStingWithName().data(using: .utf8)
        // Act
        let data = try XCTUnwrap(VCardUtils.dataWithImageAndUUID(from: profile))
        // Assert
        XCTAssertEqual(data, expectedData)
    }

    func testDataWithImageAndUUID_whenProfileAliasHasLeadingWhitespace() throws {
        // Arrange
        let profile = Profile(uri: getJamiUri(), alias: " " + profileName1, photo: photo, type: ProfileType.ring.rawValue)
        let expectedData = generateVCardStingWithNameAndImage().data(using: .utf8)
        // Act
        let data = try XCTUnwrap(VCardUtils.dataWithImageAndUUID(from: profile))
        // Assert
        XCTAssertEqual(data, expectedData)
    }

    func test_dataWithImageAndUUID_whenProfileHasNoAlias() throws {
        // Arrange
        let profile = Profile(uri: getJamiUri(), alias: nil, photo: photo, type: ProfileType.ring.rawValue)
        let expectedData = generateVCardStingWithImage().data(using: .utf8)
        // Act
        let data = try XCTUnwrap(VCardUtils.dataWithImageAndUUID(from: profile))
        // Assert
        XCTAssertEqual(data, expectedData)
    }

}
