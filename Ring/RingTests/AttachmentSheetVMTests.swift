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
import RxSwift

private final class FakeMediaLibrary: MediaLibrary {
    var access: MediaLibraryAccess
    var grantedAccess: MediaLibraryAccess = .full
    var onChange: (() -> Void)?
    var items: [GalleryItem]
    private(set) var accessRequests = 0

    init(access: MediaLibraryAccess, items: [GalleryItem]) {
        self.access = access
        self.items = items
    }

    func requestAccess(completion: @escaping (MediaLibraryAccess) -> Void) {
        accessRequests += 1
        access = grantedAccess
        completion(access)
    }

    func recentItems() -> GalleryItemList {
        items
    }

    func thumbnail(for item: GalleryItem, pixelSize: CGSize, completion: @escaping (UIImage?) -> Void) -> () -> Void {
        completion(nil)
        return {}
    }

    func export(_ item: GalleryItem, completion: @escaping (ExportedMedia?) -> Void) {
        completion(nil)
    }
}

class AttachmentSheetVMTests: XCTestCase {

    private let photo1 = GalleryItem(id: "photo1", kind: .image)
    private let photo2 = GalleryItem(id: "photo2", kind: .image)
    private let video = GalleryItem(id: "video", kind: .video, duration: 65)

    private func makeModel(access: MediaLibraryAccess = .full) -> (AttachmentSheetVM, FakeMediaLibrary) {
        let library = FakeMediaLibrary(access: access, items: [photo1, photo2, video])
        let model = AttachmentSheetVM(library: library)
        model.onAppear()
        return (model, library)
    }

    // MARK: - Access

    func testFirstAppearanceRequestsAccessAndLoadsItems() {
        let (model, library) = makeModel(access: .notDetermined)

        XCTAssertEqual(library.accessRequests, 1)
        XCTAssertEqual(model.access, .full)
        XCTAssertEqual(model.items.count, 3)
    }

    func testDeniedAccessShowsNoItems() {
        let library = FakeMediaLibrary(access: .notDetermined, items: [photo1])
        library.grantedAccess = .denied
        let model = AttachmentSheetVM(library: library)

        model.onAppear()

        XCTAssertEqual(model.access, .denied)
        XCTAssertEqual(model.items.count, 0)
    }

    func testLibraryChangeDropsSelectedItemsThatAreGone() {
        let (model, library) = makeModel()
        model.toggle(photo1)
        model.toggle(photo2)

        library.items = [photo2, video]
        library.onChange?()

        XCTAssertEqual(model.items.count, 2)
        XCTAssertEqual(model.selection, [photo2])
    }

    func testLosingAccessClearsSelection() {
        let (model, library) = makeModel()
        model.toggle(photo1)

        library.access = .denied
        library.onChange?()

        XCTAssertTrue(model.selection.isEmpty)
        XCTAssertEqual(model.items.count, 0)
    }

    // MARK: - Selection

    func testSelectionPositionFollowsTapOrder() {
        let (model, _) = makeModel()
        model.toggle(video)
        model.toggle(photo1)

        XCTAssertEqual(model.selectionPosition(of: video), 1)
        XCTAssertEqual(model.selectionPosition(of: photo1), 2)
        XCTAssertNil(model.selectionPosition(of: photo2))
    }

    func testDeselectingMovesLaterItemsUp() {
        let (model, _) = makeModel()
        model.toggle(photo1)
        model.toggle(photo2)
        model.toggle(video)

        model.toggle(photo1)

        XCTAssertNil(model.selectionPosition(of: photo1))
        XCTAssertEqual(model.selectionPosition(of: photo2), 1)
        XCTAssertEqual(model.selectionPosition(of: video), 2)
    }

    func testShowingSelectionOnlyListsTheSelection() {
        let (model, _) = makeModel()
        model.toggle(video)
        model.toggle(photo1)

        model.toggleSelectionOnly()

        XCTAssertEqual(model.visibleItems.count, 2)
        XCTAssertEqual(model.visibleItems.item(at: 0), video)
    }

    func testSelectionOnlyNeedsASelection() {
        let (model, _) = makeModel()

        model.toggleSelectionOnly()

        XCTAssertFalse(model.showsSelectionOnly)
    }

    func testDeselectingEverythingShowsAllItemsAgain() {
        let (model, _) = makeModel()
        model.toggle(photo1)
        model.toggleSelectionOnly()

        model.toggle(photo1)

        XCTAssertFalse(model.showsSelectionOnly)
        XCTAssertEqual(model.visibleItems.count, 3)
    }

    func testSendEmitsSelectionInTapOrder() {
        let (model, _) = makeModel()
        var sent: [GalleryItem]?
        let disposable = model.actions.subscribe(onNext: { action in
            if case .send(let items) = action {
                sent = items
            }
        })
        model.toggle(video)
        model.toggle(photo1)

        model.send()

        XCTAssertEqual(sent, [video, photo1])
        disposable.dispose()
    }

    func testDurationText() {
        XCTAssertEqual(AttachmentSheetVM.durationText(7), "0:07")
        XCTAssertEqual(AttachmentSheetVM.durationText(65), "1:05")
        XCTAssertEqual(AttachmentSheetVM.durationText(3_725), "1:02:05")
    }
}
