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

import AVFoundation
import Photos
import UIKit
import UniformTypeIdentifiers

struct GalleryItem: Identifiable, Equatable {
    enum Kind {
        case image
        case gif
        case video
    }

    let id: String
    let kind: Kind
    var duration: TimeInterval = 0
}

protocol GalleryItemList {
    var count: Int { get }
    var isEmpty: Bool { get }

    func item(at index: Int) -> GalleryItem
    func contains(_ id: String) -> Bool
}

extension Array: GalleryItemList where Element == GalleryItem {
    func item(at index: Int) -> GalleryItem {
        self[index]
    }

    func contains(_ id: String) -> Bool {
        contains(where: { $0.id == id })
    }
}

enum MediaLibraryAccess {
    case notDetermined
    case full
    case limited
    case denied
    /// Blocked by parental controls or device management; the user cannot change it.
    case restricted
}

enum ExportedMedia {
    case data(displayName: String, data: Data)
    /// A temporary copy the caller owns.
    case file(url: URL, displayName: String)
}

protocol MediaLibrary: AnyObject {
    var access: MediaLibraryAccess { get }
    var onChange: (() -> Void)? { get set }

    func requestAccess(completion: @escaping (MediaLibraryAccess) -> Void)
    func recentItems() -> GalleryItemList
    /// May call back twice: a quick degraded image, then the sharp one. Returns a closure that cancels the request.
    func thumbnail(for item: GalleryItem, pixelSize: CGSize, completion: @escaping (_ image: UIImage?, _ isDegraded: Bool) -> Void) -> () -> Void
    func export(_ item: GalleryItem, completion: @escaping (ExportedMedia?) -> Void)
}

final class PhotoKitMediaLibrary: MediaLibrary {
    private static let jpegQuality: CGFloat = 0.5

    var onChange: (() -> Void)?

    private let imageManager = PHCachingImageManager()
    private var assets: AssetList?
    private var changeObserver: LibraryChangeObserver?

    var access: MediaLibraryAccess {
        Self.access(for: PHPhotoLibrary.authorizationStatus(for: .readWrite))
    }

    func requestAccess(completion: @escaping (MediaLibraryAccess) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            DispatchQueue.main.async {
                completion(Self.access(for: status))
            }
        }
    }

    func recentItems() -> GalleryItemList {
        if changeObserver == nil {
            changeObserver = LibraryChangeObserver { [weak self] change in
                self?.libraryDidChange(change)
            }
        }
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.predicate = NSPredicate(format: "mediaType == %d || mediaType == %d",
                                        PHAssetMediaType.image.rawValue,
                                        PHAssetMediaType.video.rawValue)
        let list = AssetList(result: PHAsset.fetchAssets(with: options))
        assets = list
        return list
    }

    func thumbnail(for item: GalleryItem, pixelSize: CGSize, completion: @escaping (_ image: UIImage?, _ isDegraded: Bool) -> Void) -> () -> Void {
        guard let asset = asset(for: item) else {
            completion(nil, false)
            return {}
        }
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        let requestId = imageManager.requestImage(for: asset, targetSize: pixelSize, contentMode: .aspectFill, options: options) { image, info in
            completion(image, info?[PHImageResultIsDegradedKey] as? Bool ?? false)
        }
        return { [weak self] in
            self?.imageManager.cancelImageRequest(requestId)
        }
    }

    func export(_ item: GalleryItem, completion: @escaping (ExportedMedia?) -> Void) {
        guard let asset = asset(for: item) else {
            completion(nil)
            return
        }
        let resources = PHAssetResource.assetResources(for: asset)
        let baseName = resources.first.map { ($0.originalFilename as NSString).deletingPathExtension } ?? "IMG"
        if item.kind == .video {
            exportVideo(asset, baseName: baseName, completion: completion)
        } else {
            exportImage(asset, baseName: baseName, completion: completion)
        }
    }

    private func exportImage(_ asset: PHAsset, baseName: String, completion: @escaping (ExportedMedia?) -> Void) {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.version = .current
        options.isNetworkAccessAllowed = true
        imageManager.requestImageDataAndOrientation(for: asset, options: options) { data, dataUTI, _, _ in
            guard let data = data else {
                completion(nil)
                return
            }
            if let dataUTI = dataUTI, UTType(dataUTI)?.conforms(to: .gif) == true {
                completion(.data(displayName: baseName + ".gif", data: data))
                return
            }
            DispatchQueue.global(qos: .userInitiated).async {
                let jpeg = UIImage(data: data)?.jpegData(compressionQuality: Self.jpegQuality)
                completion(jpeg.map { .data(displayName: baseName + ".jpeg", data: $0) })
            }
        }
    }

    private func exportVideo(_ asset: PHAsset, baseName: String, completion: @escaping (ExportedMedia?) -> Void) {
        let options = PHVideoRequestOptions()
        options.version = .current
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        imageManager.requestAVAsset(forVideo: asset, options: options) { video, audioMix, _ in
            guard let video = video else {
                completion(nil)
                return
            }
            if let file = video as? AVURLAsset, Self.isH264(file) {
                Self.copyVideo(file.url, baseName: baseName, completion: completion)
            } else {
                Self.transcodeVideo(video, audioMix: audioMix, baseName: baseName, completion: completion)
            }
        }
    }

    private static func isH264(_ video: AVAsset) -> Bool {
        let formats = video.tracks(withMediaType: .video).flatMap { $0.formatDescriptions as? [CMFormatDescription] ?? [] }
        return !formats.isEmpty && formats.allSatisfy { CMFormatDescriptionGetMediaSubType($0) == kCMVideoCodecType_H264 }
    }

    private static func temporaryVideoURL(fileExtension: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(fileExtension)
    }

    private static func copyVideo(_ source: URL, baseName: String, completion: @escaping (ExportedMedia?) -> Void) {
        let fileExtension = source.pathExtension.isEmpty ? "mov" : source.pathExtension
        let url = temporaryVideoURL(fileExtension: fileExtension)
        do {
            try FileManager.default.copyItem(at: source, to: url)
            completion(.file(url: url, displayName: baseName + "." + fileExtension))
        } catch {
            completion(nil)
        }
    }

    private static func transcodeVideo(_ video: AVAsset, audioMix: AVAudioMix?, baseName: String, completion: @escaping (ExportedMedia?) -> Void) {
        guard let session = AVAssetExportSession(asset: video, presetName: AVAssetExportPresetHighestQuality) else {
            completion(nil)
            return
        }
        let url = temporaryVideoURL(fileExtension: "mov")
        session.outputURL = url
        session.outputFileType = .mov
        session.audioMix = audioMix
        session.exportAsynchronously {
            guard session.status == .completed else {
                try? FileManager.default.removeItem(at: url)
                completion(nil)
                return
            }
            completion(.file(url: url, displayName: baseName + ".mov"))
        }
    }

    private func asset(for item: GalleryItem) -> PHAsset? {
        assets?.asset(for: item.id)
            ?? PHAsset.fetchAssets(withLocalIdentifiers: [item.id], options: nil).firstObject
    }

    private func libraryDidChange(_ change: PHChange) {
        guard let assets = assets, change.changeDetails(for: assets.result) != nil else { return }
        onChange?()
    }

    private static func access(for status: PHAuthorizationStatus) -> MediaLibraryAccess {
        switch status {
        case .authorized:
            return .full
        case .limited:
            return .limited
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        default:
            return .denied
        }
    }
}

/// Kept out of `PhotoKitMediaLibrary` so the Photos protocol stays out of the generated Objective-C header.
private final class LibraryChangeObserver: NSObject, PHPhotoLibraryChangeObserver {
    private let onChange: (PHChange) -> Void

    init(onChange: @escaping (PHChange) -> Void) {
        self.onChange = onChange
        super.init()
        PHPhotoLibrary.shared().register(self)
    }

    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }

    func photoLibraryDidChange(_ changeInstance: PHChange) {
        DispatchQueue.main.async { [weak self] in
            self?.onChange(changeInstance)
        }
    }
}

private final class AssetList: GalleryItemList {
    let result: PHFetchResult<PHAsset>
    private var loaded = [String: PHAsset]()

    init(result: PHFetchResult<PHAsset>) {
        self.result = result
    }

    var count: Int {
        result.count
    }

    var isEmpty: Bool {
        result.firstObject == nil
    }

    func item(at index: Int) -> GalleryItem {
        let asset = result.object(at: index)
        loaded[asset.localIdentifier] = asset
        switch asset.mediaType {
        case .video:
            return GalleryItem(id: asset.localIdentifier, kind: .video, duration: asset.duration)
        default:
            return GalleryItem(id: asset.localIdentifier, kind: asset.playbackStyle == .imageAnimated ? .gif : .image)
        }
    }

    func contains(_ id: String) -> Bool {
        guard let asset = loaded[id] ?? PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject else { return false }
        return result.contains(asset)
    }

    func asset(for id: String) -> PHAsset? {
        loaded[id]
    }
}
