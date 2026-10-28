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

    init(access: MediaLibraryAccess, items: [GalleryItem] = []) {
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
    private let gif = GalleryItem(id: "gif", kind: .gif)
    private let video = GalleryItem(id: "video", kind: .video, duration: 65)

    private var disposeBag: DisposeBag!

    override func setUp() {
        super.setUp()
        disposeBag = DisposeBag()
    }

    override func tearDown() {
        disposeBag = nil
        super.tearDown()
    }

    private func makeModel(access: MediaLibraryAccess = .full, items: [GalleryItem]? = nil) -> (AttachmentSheetVM, FakeMediaLibrary) {
        let library = FakeMediaLibrary(access: access, items: items ?? [photo1, photo2, gif, video])
        let model = AttachmentSheetVM(library: library)
        model.onAppear()
        return (model, library)
    }

    private func recordActions(of model: AttachmentSheetVM) -> () -> [AttachmentSheetVM.Action] {
        var actions = [AttachmentSheetVM.Action]()
        model.actions
            .subscribe(onNext: { actions.append($0) })
            .disposed(by: disposeBag)
        return { actions }
    }

    // MARK: - Access

    func testFirstAppearanceRequestsAccessAndLoadsItems() {
        let (model, library) = makeModel(access: .notDetermined)

        XCTAssertEqual(library.accessRequests, 1)
        XCTAssertEqual(model.access, .full)
        XCTAssertEqual(model.items.count, 4)
    }

    func testGrantedAccessIsNotRequestedAgain() {
        let (_, library) = makeModel(access: .limited)

        XCTAssertEqual(library.accessRequests, 0)
    }

    func testDeniedAccessShowsNoItems() {
        let library = FakeMediaLibrary(access: .notDetermined, items: [photo1])
        library.grantedAccess = .denied
        let model = AttachmentSheetVM(library: library)

        model.onAppear()

        XCTAssertEqual(model.access, .denied)
        XCTAssertFalse(model.canBrowseLibrary)
        XCTAssertEqual(model.items.count, 0)
    }

    // MARK: - Selection

    func testSelectionIsNumberedInTapOrder() {
        let (model, _) = makeModel()

        model.toggle(video)
        model.toggle(photo1)

        XCTAssertEqual(model.selectionNumber(of: video), 1)
        XCTAssertEqual(model.selectionNumber(of: photo1), 2)
        XCTAssertNil(model.selectionNumber(of: photo2))
    }

    func testDeselectingRenumbersTheRest() {
        let (model, _) = makeModel()
        model.toggle(photo1)
        model.toggle(photo2)
        model.toggle(video)

        model.toggle(photo1)

        XCTAssertNil(model.selectionNumber(of: photo1))
        XCTAssertEqual(model.selectionNumber(of: photo2), 1)
        XCTAssertEqual(model.selectionNumber(of: video), 2)
    }

    func testClearSelection() {
        let (model, _) = makeModel()
        model.toggle(photo1)
        model.toggle(video)

        model.clearSelection()

        XCTAssertTrue(model.selection.isEmpty)
    }

    func testSummaryCountsGifsAsPhotos() {
        let (model, _) = makeModel()
        model.toggle(photo1)
        model.toggle(gif)
        model.toggle(video)

        XCTAssertEqual(model.photoCount, 2)
        XCTAssertEqual(model.videoCount, 1)
    }

    func testTitleShowsSelectionCount() {
        let (model, _) = makeModel()
        XCTAssertEqual(model.title, L10n.AttachmentSheet.title)

        model.toggle(photo1)
        model.toggle(photo2)

        XCTAssertEqual(model.title, L10n.AttachmentSheet.selected(2))
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

    // MARK: - Sending

    func testSendEmitsSelectionInOrderWithCaption() {
        let (model, _) = makeModel()
        let actions = recordActions(of: model)
        model.toggle(video)
        model.toggle(photo1)
        model.caption = "Holidays"

        model.send()

        guard case .send(let items, let caption)? = actions().last else {
            return XCTFail("Expected a send action")
        }
        XCTAssertEqual(items, [video, photo1])
        XCTAssertEqual(caption, "Holidays")
    }

    func testSendWithoutSelectionDoesNothing() {
        let (model, _) = makeModel()
        let actions = recordActions(of: model)
        model.caption = "Only text"

        model.send()

        XCTAssertTrue(actions().isEmpty)
    }

    // MARK: - Formatting

    func testDurationText() {
        XCTAssertEqual(AttachmentSheetVM.durationText(7), "0:07")
        XCTAssertEqual(AttachmentSheetVM.durationText(65), "1:05")
        XCTAssertEqual(AttachmentSheetVM.durationText(3_725), "1:02:05")
    }
}
