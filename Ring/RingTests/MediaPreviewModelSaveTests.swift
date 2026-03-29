/*
 *  Copyright (C) 2026-2026 Savoir-faire Linux Inc.
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

@testable import Ring
import XCTest
import Combine
import Photos

private class MockPreviewDelegate: MediaPreviewActionsDelegate {
    func deleteMessage() {}
}

class MediaPreviewModelSaveTests: XCTestCase {

    private var mockSaver: MockPhotoLibrarySaver!
    private var delegate: MockPreviewDelegate!
    private var imageURL: URL!
    private var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        mockSaver = MockPhotoLibrarySaver()
        delegate = MockPreviewDelegate()
        imageURL = URL(fileURLWithPath: "/tmp/test-image.jpg")
        cancellables = []
    }

    override func tearDown() {
        mockSaver = nil
        delegate = nil
        imageURL = nil
        cancellables = nil
        super.tearDown()
    }

    private func makeModel(url: URL? = nil) -> MediaPreviewModel {
        let image = UIImage()
        return MediaPreviewModel(
            content: .image(image),
            delegate: delegate,
            fileURL: url ?? imageURL,
            canDelete: false,
            photoSaver: mockSaver
        )
    }

    // MARK: - Tests

    func test_save_whenAuthorized_callsPerformSave() {
        mockSaver.stubbedStatus = .authorized
        let model = makeModel()

        model.save()

        XCTAssertTrue(mockSaver.authorizationStatusCalled)
        XCTAssertTrue(mockSaver.performSaveCalled)
        XCTAssertEqual(mockSaver.performSaveURL, imageURL)
    }

    func test_save_whenAuthorized_setsSuccessOnSuccess() {
        mockSaver.stubbedStatus = .authorized
        mockSaver.stubbedSaveResult = .success
        let model = makeModel()

        let exp = expectation(description: "saveSuccess set")
        model.$saveSuccess
            .dropFirst()
            .sink { value in
                if value { exp.fulfill() }
            }
            .store(in: &cancellables)

        model.save()

        wait(for: [exp], timeout: 1.0)
        XCTAssertTrue(model.saveSuccess)
        XCTAssertNil(model.saveError)
    }

    func test_save_whenDenied_setsNeedsPhotoPermission() {
        mockSaver.stubbedStatus = .denied
        let model = makeModel()

        let exp = expectation(description: "needsPhotoPermission set")
        model.$needsPhotoPermission
            .dropFirst()
            .sink { value in
                if value { exp.fulfill() }
            }
            .store(in: &cancellables)

        model.save()

        wait(for: [exp], timeout: 1.0)
        XCTAssertTrue(model.needsPhotoPermission)
        XCTAssertFalse(mockSaver.performSaveCalled)
    }

    func test_save_whenNotDetermined_requestsAuthThenSaves() {
        mockSaver.stubbedStatus = .notDetermined
        mockSaver.stubbedRequestResult = .authorized
        mockSaver.stubbedSaveResult = .success
        let model = makeModel()

        let exp = expectation(description: "saveSuccess set")
        model.$saveSuccess
            .dropFirst()
            .sink { value in
                if value { exp.fulfill() }
            }
            .store(in: &cancellables)

        model.save()

        wait(for: [exp], timeout: 1.0)
        XCTAssertTrue(mockSaver.requestAuthorizationCalled)
        XCTAssertTrue(mockSaver.performSaveCalled)
        XCTAssertTrue(model.saveSuccess)
    }

    func test_save_whenNotDetermined_andDenied_setsError() {
        mockSaver.stubbedStatus = .notDetermined
        mockSaver.stubbedRequestResult = .denied
        let model = makeModel()

        let exp = expectation(description: "saveError set")
        model.$saveError
            .dropFirst()
            .sink { value in
                if value != nil { exp.fulfill() }
            }
            .store(in: &cancellables)

        model.save()

        wait(for: [exp], timeout: 1.0)
        XCTAssertTrue(mockSaver.requestAuthorizationCalled)
        XCTAssertFalse(mockSaver.performSaveCalled)
        XCTAssertNotNil(model.saveError)
    }

    func test_save_whenSaveFails_setsSaveError() {
        mockSaver.stubbedStatus = .authorized
        mockSaver.stubbedSaveResult = .error("Disk full")
        let model = makeModel()

        let exp = expectation(description: "saveError set")
        model.$saveError
            .dropFirst()
            .sink { value in
                if value != nil { exp.fulfill() }
            }
            .store(in: &cancellables)

        model.save()

        wait(for: [exp], timeout: 1.0)
        XCTAssertTrue(mockSaver.performSaveCalled)
        XCTAssertEqual(model.saveError, "Disk full")
        XCTAssertFalse(model.saveSuccess)
    }
}
