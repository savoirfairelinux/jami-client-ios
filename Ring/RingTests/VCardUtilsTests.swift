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

    func testLocalOverrideOmitsFieldsThatWereNotCustomized() throws {
        let profile = Profile(uri: getJamiUri(),
                              alias: profileName1,
                              photo: nil,
                              type: ProfileType.ring.rawValue)

        let data = try XCTUnwrap(VCardUtils.vCardData(for: profile))
        let parsed = VCardUtils.parseDataToProfile(data: data)

        XCTAssertEqual(parsed?.alias, profileName1)
        XCTAssertNil(parsed?.photo)
    }

    func testLocalOverrideCanBeReadWithoutRemoteProfile() throws {
        let profile = Profile(uri: getJamiUri(),
                              alias: profileName1,
                              photo: photo,
                              type: ProfileType.ring.rawValue)
        let data = try XCTUnwrap(VCardUtils.vCardData(for: profile))
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("vcf")
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let parsed = VCardUtils.parseMergedProfile(basePath: nil,
                                                   overridePath: url.path)

        XCTAssertEqual(parsed?.alias, profileName1)
        XCTAssertEqual(parsed?.photo, photo)
    }
}

final class ProfilePathHelperTests: XCTestCase {

    private let accountId = "0123456789abcdef"
    private var documents: URL!

    private var profilePhoto: String { "profile-photo" }
    private var legacyPhoto: String { "legacy-photo" }
    private var jamsPhoto: String { "jams-photo" }
    private var invitationPhoto: String { "invitation-photo" }

    override func setUpWithError() throws {
        try super.setUpWithError()
        documents = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: profilesFolder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: documents)
        documents = nil
        try super.tearDownWithError()
    }

    private var profilesFolder: URL {
        documents
            .appendingPathComponent(accountId, isDirectory: true)
            .appendingPathComponent("profiles", isDirectory: true)
    }

    private func vCard(photo: String) -> Data {
        Data("""
        BEGIN:VCARD
        FN:\(profileName1)
        TEL;other:ring:\(jamiId1)
        PHOTO;ENCODING=BASE64;TYPE=JPEG:\(photo)
        END:VCARD
        """.utf8)
    }

    @discardableResult
    private func writeProfile(photo: String) throws -> URL {
        let encoded = Data(jamiId1.utf8).base64EncodedString()
        let url = profilesFolder.appendingPathComponent("\(encoded).vcf")
        try vCard(photo: photo).write(to: url)
        return url
    }

    @discardableResult
    private func writeLegacyProfile(photo: String) throws -> URL {
        let encoded = Data("jami:\(jamiId1)".utf8).base64EncodedString()
        let url = profilesFolder.appendingPathComponent("\(encoded).vcf")
        try vCard(photo: photo).write(to: url)
        return url
    }

    @discardableResult
    private func writeManagedProfile(folder: ManagedProfileFolder, photo: String) throws -> URL {
        let path = try XCTUnwrap(ProfilePathHelper.profilePath(accountId: accountId,
                                                               contactId: "jami:\(jamiId1)",
                                                               folder: folder,
                                                               documents: documents,
                                                               createIfNotExists: true))
        let url = URL(fileURLWithPath: path)
        try vCard(photo: photo).write(to: url)
        return url
    }

    private func resolvedPhoto(for contactId: String) -> String? {
        guard let path = ProfilePathHelper.existingContactProfilePath(accountId: accountId,
                                                                      contactId: contactId,
                                                                      documents: documents) else { return nil }
        return VCardUtils.parseToProfile(filePath: path)?.photo
    }

    func testProfileWinsOverLegacyProfile() throws {
        // Arrange
        try writeLegacyProfile(photo: legacyPhoto)
        try writeProfile(photo: profilePhoto)
        // Act
        let resolved = resolvedPhoto(for: "jami:\(jamiId1)")
        // Assert
        XCTAssertEqual(resolved, profilePhoto)
    }

    func testLegacyProfileIsUsedWhenProfileIsMissing() throws {
        // Arrange
        try writeLegacyProfile(photo: legacyPhoto)
        // Act
        let resolved = resolvedPhoto(for: "jami:\(jamiId1)")
        // Assert
        XCTAssertEqual(resolved, legacyPhoto)
    }

    func testProfileIsFoundWithoutLegacyProfile() throws {
        // Arrange
        try writeProfile(photo: profilePhoto)
        // Act
        let resolved = resolvedPhoto(for: "jami:\(jamiId1)")
        // Assert
        XCTAssertEqual(resolved, profilePhoto)
    }

    func testProfileIsFoundWhateverTheURIForm() throws {
        // Arrange
        try writeProfile(photo: profilePhoto)
        // Act & Assert
        for contactId in [jamiId1, "ring:\(jamiId1)", "jami:\(jamiId1)", "<\(jamiId1)@ring.dht>"] {
            XCTAssertEqual(resolvedPhoto(for: contactId), profilePhoto, "failed for \(contactId)")
        }
    }

    func testLegacyProfileWinsOverManagedProfiles() throws {
        try writeLegacyProfile(photo: legacyPhoto)
        try writeManagedProfile(folder: .jamsSearch, photo: jamsPhoto)
        try writeManagedProfile(folder: .invitation, photo: invitationPhoto)

        XCTAssertEqual(resolvedPhoto(for: jamiId1), legacyPhoto)
    }

    func testContactProfileWinsOverManagedProfiles() throws {
        try writeProfile(photo: profilePhoto)
        try writeManagedProfile(folder: .jamsSearch, photo: jamsPhoto)
        try writeManagedProfile(folder: .invitation, photo: invitationPhoto)

        XCTAssertEqual(resolvedPhoto(for: jamiId1), profilePhoto)
    }

    func testJamsProfileWinsOverInvitationProfile() throws {
        try writeManagedProfile(folder: .jamsSearch, photo: jamsPhoto)
        try writeManagedProfile(folder: .invitation, photo: invitationPhoto)

        XCTAssertEqual(resolvedPhoto(for: jamiId1), jamsPhoto)
    }

    func testInvitationProfileIsUsedWhenOtherProfilesAreMissing() throws {
        try writeManagedProfile(folder: .invitation, photo: invitationPhoto)

        XCTAssertEqual(resolvedPhoto(for: jamiId1), invitationPhoto)
    }

    func testNoProfileResolvesToNil() {
        XCTAssertNil(ProfilePathHelper.existingContactProfilePath(accountId: accountId,
                                                                  contactId: jamiId1,
                                                                  documents: documents))
    }
}
