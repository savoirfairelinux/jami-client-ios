/*
 *  Copyright (C) 2004-2026 Savoir-faire Linux Inc.
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
 *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

import XCTest
@testable import Ring

/// Putting the pictures back into an exported document.
///
/// The page names each picture instead of carrying it, and this side has the
/// bytes. What it must not do is take one name for another: the ids are opaque,
/// so one can begin with another, and the address of a picture is followed by a
/// bracket in markdown, which an id is allowed to contain.
class CollabExportTests: XCTestCase {
    private var injectionBag: InjectionBag!
    private var viewModel: CollabEditorViewModel!

    /// What the page draws afresh for every export.
    private let scheme = "jami-attachment-0123456789abcdef0123456789abcdef:"

    override func setUpWithError() throws {
        try super.setUpWithError()
        let dbManager = DBManager(conversationHelper: ConversationDataHelper(),
                                  interactionHepler: InteractionDataHelper(),
                                  dbConnections: DBContainer())
        injectionBag = InjectionBag(
            withDaemonService: DaemonService(dRingAdaptor: DRingAdapter()),
            withAccountService: AccountsService(withAccountAdapter: AccountAdapter(),
                                                dbManager: dbManager),
            withNameService: NameService(withNameRegistrationAdapter: NameRegistrationAdapter()),
            withConversationService: ConversationsService(
                withConversationsAdapter: ConversationsAdapter(), dbManager: dbManager),
            withContactsService: ContactsService(withContactsAdapter: ContactsAdapter(),
                                                 dbManager: dbManager),
            withPresenceService: PresenceService(withPresenceAdapter: PresenceAdapter()),
            withNetworkService: NetworkService(),
            withCallService: CallService(),
            withVideoService: VideoService(),
            withAudioService: AudioService(),
            withDataTransferService: DataTransferService(
                withDataTransferAdapter: DataTransferAdapter(), dbManager: dbManager),
            withProfileService: ProfilesService(withProfilesAdapter: ProfilesAdapter(),
                                                dbManager: dbManager),
            withLocationSharingService: LocationSharingService(dbManager: dbManager),
            withRequestsService: RequestsService(withRequestsAdapter: RequestsAdapter(),
                                                 dbManager: dbManager),
            withSystemService: SystemService(withSystemAdapter: SystemAdapter()),
            withPeerSharingService: TestPeerSharingFactory.createService(),
            withCollaborationService: CollaborationService(
                withCollaborationAdapter: ObjCMockCollaborationAdapter()))
        viewModel = CollabEditorViewModel(with: injectionBag,
                                          accountId: "account",
                                          conversationId: "conversation",
                                          documentId: "document",
                                          name: nil)
    }

    override func tearDownWithError() throws {
        try super.tearDownWithError()
        injectionBag = nil
        viewModel = nil
    }

    /// A PNG signature and the start of its header, which is what the mime
    /// type is read from.
    private var png: Data {
        Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
              0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52])
    }

    func testEmbedPutsEveryPictureBackWhereItsNameWas() {
        let text = "<p>before <img src=\"\(scheme)aa11\">"
            + " and <img src=\"\(scheme)aa1122\"> after</p>"
        let written = viewModel.embed(["aa11": png, "aa1122": png], in: text, under: scheme)

        XCTAssertFalse(written.contains(scheme), "a picture kept its name")
        XCTAssertEqual(written.components(separatedBy: "data:image/png;base64,").count - 1, 2)
    }

    /// An id can begin with another, and taking the shorter one would leave the
    /// tail of the longer sitting in the middle of an address.
    func testEmbedDoesNotTakeOneNameForTheStartOfAnother() {
        let text = "![](\(scheme)aa1122)"
        let written = viewModel.embed(["aa11": png, "aa1122": png], in: text, under: scheme)

        XCTAssertFalse(written.contains("22)"), "the longer id was cut short")
        XCTAssertTrue(written.hasSuffix(")"), "the picture lost its closing bracket")
    }

    /// A bracket closes a picture in markdown and is one of the characters an
    /// id is left holding, so a name cannot be read as running up to one.
    func testEmbedLeavesMarkdownAroundThePictureAlone() {
        let text = "before ![](\(scheme)aa11) after"
        let written = viewModel.embed(["aa11": png], in: text, under: scheme)

        XCTAssertTrue(written.hasPrefix("before !["), written)
        XCTAssertTrue(written.hasSuffix(") after"), written)
        XCTAssertFalse(written.contains(scheme))
    }

    /// The document is written again without a picture whose bytes never came,
    /// so nothing here may leave an address that leads nowhere in its place.
    func testEmbedLeavesAPictureThatNeverArrivedNamed() {
        let text = "![](\(scheme)aa11) ![](\(scheme)aa1122)"
        let written = viewModel.embed(["aa11": png, "aa1122": Data()],
                                      in: text, under: scheme)

        XCTAssertTrue(written.contains("![](\(scheme)aa1122)"), written)
        XCTAssertEqual(written.components(separatedBy: "data:image/png;base64,").count - 1, 1)
    }

    func testEmbedLeavesADocumentWithoutPicturesAsItIs() {
        let text = "<p>nothing to put back</p>"
        XCTAssertEqual(viewModel.embed([:], in: text, under: scheme), text)
    }
}
