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

import Foundation
import RxSwift
import UIKit

final class AttachmentSheetVM: ObservableObject {
    enum Action {
        case close
        case takePhoto
        case browseAllPhotos
        case manageLimitedAccess
        case openSettings
        case send(items: [GalleryItem])
    }

    @Published private(set) var access: MediaLibraryAccess
    @Published private(set) var items: GalleryItemList = [GalleryItem]()
    @Published private(set) var selection: [GalleryItem] = [] {
        didSet {
            if selection.isEmpty {
                showsSelectionOnly = false
            }
        }
    }
    @Published private(set) var showsSelectionOnly = false

    let actions = PublishSubject<Action>()
    let disposeBag = DisposeBag()
    private let library: MediaLibrary

    init(library: MediaLibrary) {
        self.library = library
        access = library.access
        library.onChange = { [weak self] in
            self?.reload()
        }
    }

    var title: String {
        selection.isEmpty ? L10n.AttachmentSheet.title : L10n.AttachmentSheet.selected(selection.count)
    }

    private var canBrowseLibrary: Bool {
        access == .full || access == .limited
    }

    var canOpenSettings: Bool {
        access == .denied
    }

    var visibleItems: GalleryItemList {
        if showsSelectionOnly {
            return selection
        }
        return items
    }

    var summary: String {
        let photos = selection.filter { $0.kind != .video }.count
        let videos = selection.count - photos
        var parts = [String]()
        if photos > 0 {
            parts.append(photos == 1 ? L10n.AttachmentSheet.onePhoto : L10n.AttachmentSheet.photos(photos))
        }
        if videos > 0 {
            parts.append(videos == 1 ? L10n.AttachmentSheet.oneVideo : L10n.AttachmentSheet.videos(videos))
        }
        return ListFormatter.localizedString(byJoining: parts)
    }

    func onAppear() {
        guard access == .notDetermined else {
            reload()
            return
        }
        library.requestAccess { [weak self] _ in
            self?.reload()
        }
    }

    private func reload() {
        access = library.access
        guard canBrowseLibrary else {
            items = [GalleryItem]()
            selection.removeAll()
            return
        }
        let items = library.recentItems()
        selection.removeAll { !items.contains($0.id) }
        self.items = items
    }

    /// 1-based place in the send order, or nil when not selected.
    func selectionPosition(of item: GalleryItem) -> Int? {
        selection.firstIndex(where: { $0.id == item.id }).map { $0 + 1 }
    }

    func accessibilityValue(forPosition position: Int?) -> String {
        position.map { L10n.Accessibility.attachmentSheetPosition($0, selection.count) } ?? ""
    }

    func toggle(_ item: GalleryItem) {
        if let index = selection.firstIndex(where: { $0.id == item.id }) {
            selection.remove(at: index)
        } else {
            selection.append(item)
        }
    }

    func toggleSelectionOnly() {
        guard showsSelectionOnly || !selection.isEmpty else { return }
        showsSelectionOnly.toggle()
    }

    func send() {
        guard !selection.isEmpty else { return }
        actions.onNext(.send(items: selection))
    }

    func perform(_ action: Action) {
        actions.onNext(action)
    }

    func thumbnail(for item: GalleryItem, pixelSize: CGSize, completion: @escaping (_ image: UIImage?, _ isDegraded: Bool) -> Void) -> () -> Void {
        library.thumbnail(for: item, pixelSize: pixelSize, completion: completion)
    }

    func accessibilityLabel(for item: GalleryItem) -> String {
        switch item.kind {
        case .image:
            return L10n.Accessibility.attachmentSheetPhoto
        case .gif:
            return L10n.AttachmentSheet.gif
        case .video:
            return L10n.Accessibility.attachmentSheetVideo(Self.durationText(item.duration))
        }
    }

    private static let shortDurationFormatter = durationFormatter(units: [.minute, .second])
    private static let longDurationFormatter = durationFormatter(units: [.hour, .minute, .second])

    private static func durationFormatter(units: NSCalendar.Unit) -> DateComponentsFormatter {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .positional
        formatter.allowedUnits = units
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }

    static func durationText(_ duration: TimeInterval) -> String {
        let rounded = duration.rounded()
        let formatter = rounded >= 3600 ? longDurationFormatter : shortDurationFormatter
        return formatter.string(from: rounded) ?? ""
    }
}
