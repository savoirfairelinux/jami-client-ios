/*
 *  Copyright (C) 2018-2019 Savoir-faire Linux Inc.
 *
 *  Author: Andreas Traczyk <andreas.traczyk@savoirfairelinux.com>
 *  Author: Quentin Muret <quentin.muret@savoirfairelinux.com>
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

import SwiftyBeaver
import RxSwift
import Foundation
import MobileCoreServices
import Photos

// swiftlint:disable identifier_name

enum DataTransferServiceError: Error {
    case createTransferError
    case updateTransferError
}

enum Directories: String {
    case recorded
    case downloads
}

enum DataTransferStatus: CustomStringConvertible {
    var description: String {
        switch self {
        case .created: return "created"
        case .awaiting: return "awaiting"
        case .canceled: return "canceled"
        case .ongoing: return "ongoing"
        case .success: return "success"
        case .error: return "error"
        case .unknown: return "unknown"
        }
    }

    case created
    case awaiting
    case canceled
    case ongoing
    case success
    case error
    case unknown
}

// swiftlint:disable cyclomatic_complexity
func stringFromEventCode(with code: NSDataTransferEventCode) -> String {
    switch code {
    case .invalid: return "Invalid"
    case .created: return "initializing transfer"
    case .unsupported: return "unsupported"
    case .wait_host_acceptance: return "waiting peer acceptance"
    case .wait_peer_acceptance: return "waiting host acceptance"
    case .ongoing: return "ongoing"
    case .finished: return "finished"
    case .closed_by_host: return "closed by host"
    case .closed_by_peer: return "closed by peer"
    case .invalid_pathname: return "invalid pathname"
    case .unjoinable_peer: return "unjoinable peer"
    @unknown default:
       return "Invalid"
    }
}
// swiftlint:enable cyclomatic_complexity

public final class DataTransferService: DataTransferAdapterDelegate {

    private let log = SwiftyBeaver.self

    //contain image if transfering file is image type, othewise contain nil
    typealias ImageTuple = (isImage: Bool, data: UIImage?)
    private var transferedImages = [String: ImageTuple]()

    fileprivate let dataTransferAdapter: DataTransferAdapter

    fileprivate let disposeBag = DisposeBag()
    fileprivate let responseStream = PublishSubject<ServiceEvent>()
    var sharedResponseStream: Observable<ServiceEvent>
    let dbManager: DBManager

    init(withDataTransferAdapter dataTransferAdapter: DataTransferAdapter, dbManager: DBManager) {
        self.responseStream.disposed(by: disposeBag)
        self.sharedResponseStream = responseStream.share()
        self.dataTransferAdapter = dataTransferAdapter
        self.dbManager = dbManager
        DataTransferAdapter.delegate = self
    }
    // MARK: public

    func getTransferInfo(withId transferId: UInt64) -> NSDataTransferInfo? {
        let info = NSDataTransferInfo()
        let err = self.dataTransferAdapter.dataTransferInfo(withId: transferId, with: info)
        if err != .success {
            self.log.error("DataTransferService: error getting transfer info for id: \(transferId)")
            return nil
        }
        return info
    }

    func acceptTransfer(withId transferId: UInt64,
                        interactionID: Int64,
                        fileName: inout String,
                        accountID: String,
                        conversationID: String) -> NSDataTransferError {
        guard let info = getTransferInfo(withId: transferId) else {
            return NSDataTransferError.invalid_argument
        }
        // accept transfer
        if let pathUrl = getFilePathForTransfer(forFile: info.displayName, accountID: accountID,
                                                conversationID: conversationID) {
            // if file name was changed because the same name already exist, update db
            if pathUrl.lastPathComponent != info.displayName {
                let fileSizeWithUnit = ByteCountFormatter.string(fromByteCount: info.totalSize, countStyle: .file)
                let name = pathUrl.lastPathComponent + "\n" + fileSizeWithUnit
                fileName = name
                //update db
                self.dbManager.updateFileName(interactionID: interactionID, name: name, accountId: accountID).subscribe(onCompleted: { [weak self] in
                      self?.log.debug("file name updated")
                }, onError: { [weak self] _ in
                     self?.log.error("update name failed")
                }).disposed(by: self.disposeBag)
            }
            self.log.debug("DataTransferService: saving file to: \(pathUrl.path))")
            return acceptFileTransfer(withId: transferId, withPath: pathUrl.path)
        } else {
            self.log.error("DataTransferService: saving file error: bad local path")
            return .io
        }
    }

    func getFileUrl(fileName: String,
                    inFolder: String,
                    accountID: String,
                    conversationID: String) -> URL? {
        guard let pathUrl = getFilePath(fileName: fileName,
                                        inFolder: inFolder,
                                        accountID: accountID,
                                        conversationID: conversationID) else { return nil }
        let fileManager = FileManager.default
        var file: URL?
        if fileManager.fileExists(atPath: pathUrl.path) {
            file = NSURL.fileURL(withPath: pathUrl.path)
        }
        return file
    }

    /*
     to avoid creating images multiple time keep images in dictionary
     images saved in app document folder referenced by conversationId concatinated with image name
     images from photo librairy referenced by local identifier
    */

    func getImage(for name: String, maxSize: CGFloat, identifier: String? = nil,
                  accountID: String, conversationID: String) -> UIImage? {
        if let localImageIdentifier = identifier {
            if let image = self.transferedImages[localImageIdentifier] {
                return image.data
            }
            return self.getImageFromPhotoLibrairy(identifier: localImageIdentifier, maxSize: maxSize, name: name)
        }
        if let image = self.transferedImages[conversationID + name] {
            return image.data
        }
        return self.getImageFromFile(for: name, maxSize: maxSize, accountID: accountID,
                                     conversationID: conversationID)
    }

    func getImageFromPhotoLibrairy(identifier: String, maxSize: CGFloat, name: String) -> UIImage? {
        let imageManager = PHImageManager.default()
        let requestOptions = PHImageRequestOptions()
        requestOptions.resizeMode = PHImageRequestOptionsResizeMode.fast
        requestOptions.deliveryMode = PHImageRequestOptionsDeliveryMode.fastFormat
        requestOptions.isSynchronous = true
        var photo: UIImage?
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: PHFetchOptions()).firstObject else {
            return photo
        }
        imageManager.requestImage(for: asset, targetSize: CGSize(width: maxSize, height: maxSize), contentMode: .aspectFit, options: requestOptions, resultHandler: {(result, _) -> Void in
            guard let image = result else { return }
            self.transferedImages[identifier] = (true, image)
            photo = image
        })
        return photo
    }

    func getImageFromFile(for name: String,
                          maxSize: CGFloat,
                          accountID: String,
                          conversationID: String) -> UIImage? {
        guard let pathUrl = getFilePath(fileName: name,
                                        inFolder: Directories.downloads.rawValue,
                                        accountID: accountID,
                                        conversationID: conversationID) else { return nil }
        let fileExtension = pathUrl.pathExtension as CFString
        guard let uti = UTTypeCreatePreferredIdentifierForTag(
            kUTTagClassFilenameExtension,
            fileExtension,
            nil) else { return nil }
        if UTTypeConformsTo(uti.takeRetainedValue(), kUTTypeImage) {
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: pathUrl.path) {
                if fileExtension as String == "gif" {
                    let image = UIImage.gifImageWithUrl(pathUrl)
                    return image
                }
                let image = UIImage(contentsOfFile: pathUrl.path)
                self.transferedImages[conversationID + name] = (true, image)
                return image
            }
        } else {
            self.transferedImages[conversationID + name] = (false, nil)
        }
        return nil
    }

    func isTransferImage(withId transferId: UInt64, accountID: String, conversationID: String) -> Bool? {
        guard let info = getTransferInfo(withId: transferId) else { return nil }
        guard let pathUrl = getFilePath(fileName: info.displayName,
                                        inFolder: Directories.downloads.rawValue,
                                        accountID: accountID,
                                        conversationID: conversationID) else { return nil }
        let fileExtension = pathUrl.pathExtension as CFString
        guard let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension,
                                                              fileExtension,
                                                              nil) else { return nil }
        return UTTypeConformsTo(uti.takeRetainedValue(), kUTTypeImage)
    }

    func cancelTransfer(withId transferId: UInt64) -> NSDataTransferError {
        let err = cancelDataTransfer(withId: transferId)
        if err != .success {
            self.log.error("couldn't cancel transfer with id: \(transferId)")
        }
        return err
    }

    func sendFile(filePath: String, displayName: String, accountId: String, peerInfoHash: String, localIdentifier: String?) {
        var transferId: UInt64 = 0
        let info = NSDataTransferInfo()
        info.accountId = accountId
        info.peer = peerInfoHash
        info.path = filePath
        info.mimetype = ""
        info.displayName = displayName
        let err = sendFile(withId: &transferId, withInfo: info)
        if err != .success {
            self.log.error("sendFile failed")
        } else {
            let serviceEventType: ServiceEventType = .dataTransferCreated
            var serviceEvent = ServiceEvent(withEventType: serviceEventType)
            serviceEvent.addEventInput(.transferId, value: transferId)
            if let localIdentifier = localIdentifier {
                serviceEvent.addEventInput(.localPhotolID, value: localIdentifier)
            }
            self.responseStream.onNext(serviceEvent)
        }
    }

    func sendAndSaveFile(displayName: String,
                         accountId: String,
                         peerInfoHash: String,
                         imageData: Data,
                         conversationId: String) {
        guard let imagePath = self.getFilePathForTransfer(forFile: displayName,
                                                          accountID: accountId,
                                                          conversationID: conversationId) else { return }
        do {
            try imageData.write(to: URL(fileURLWithPath: imagePath.path), options: .atomic)
        } catch {
            self.log.error("couldn't copy image to cache")
        }
        self.sendFile(filePath: imagePath.path, displayName: imagePath.lastPathComponent, accountId: accountId, peerInfoHash: peerInfoHash, localIdentifier: nil)
    }

    func getTransferProgress(withId transferId: UInt64) -> Float? {
        var total: Int64 = 0
        var progress: Int64 = 0
        let err = dataTransferBytesProgress(withId: transferId, withTotal: &total, withProgress: &progress)
        if err != .success {
            return nil
        }
        let progressValue = Float(progress) / Float(total)
        return progressValue
    }

    // MARK: private

    fileprivate func getFilePath(fileName: String, inFolder: String, accountID: String, conversationID: String) -> URL? {
        let folderName = inFolder
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let directoryURL = documentsURL.appendingPathComponent(folderName)
            .appendingPathComponent(accountID).appendingPathComponent(conversationID)
        return directoryURL.appendingPathComponent(fileName)
    }

    fileprivate func getFilePathForDirectory(directory: String, fileName: String, accountID: String, conversationID: String) -> URL? {
        let folderName = directory
        let fileNameOnly = (fileName as NSString).deletingPathExtension
        let fileExtensionOnly = (fileName as NSString).pathExtension
        var filePathUrl: URL?
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let directoryURL = documentsURL.appendingPathComponent(folderName)
            .appendingPathComponent(accountID).appendingPathComponent(conversationID)
        var isDirectory = ObjCBool(false)
        let directoryExists = FileManager.default.fileExists(atPath: directoryURL.path, isDirectory: &isDirectory)
        if directoryExists && isDirectory.boolValue {
            if directory == Directories.recorded.rawValue {
                return directoryURL.appendingPathComponent(fileName, isDirectory: false)
            }
            // check if file exists, if so add " (<duplicates+1>)" or "_<duplicates+1>"
            // first check /.../AppData/Documents/directory/<fileNameOnly>.<fileExtensionOnly>
            var finalFileName = fileNameOnly + "." + fileExtensionOnly
            var filePathCheck = directoryURL.appendingPathComponent(finalFileName)
            var fileExists = FileManager.default.fileExists(atPath: filePathCheck.path, isDirectory: &isDirectory)
            var duplicates = 2
            while fileExists {
                // check /.../AppData/Documents/directory/<fileNameOnly>_<duplicates>.<fileExtensionOnly>
                finalFileName = fileNameOnly + "_" + String(duplicates) + "." + fileExtensionOnly
                filePathCheck = directoryURL.appendingPathComponent(finalFileName)
                fileExists = FileManager.default.fileExists(atPath: filePathCheck.path, isDirectory: &isDirectory)
                duplicates += 1
            }
            return filePathCheck
        }
        // need to create dir
        do {
            try FileManager.default.createDirectory(atPath: directoryURL.path, withIntermediateDirectories: true, attributes: nil)
            filePathUrl = directoryURL.appendingPathComponent(fileName, isDirectory: false)
            return filePathUrl
        } catch _ as NSError {
            self.log.error("DataTransferService: error creating dir")
            return nil
        }
    }

    fileprivate func getFilePathForTransfer(forFile fileName: String, accountID: String, conversationID: String) -> URL? {
        return self.getFilePathForDirectory(directory: Directories.downloads.rawValue,
                                            fileName: fileName,
                                            accountID: accountID,
                                            conversationID: conversationID)
    }

    func getFilePathForRecordings(forFile fileName: String, accountID: String, conversationID: String) -> URL? {
        return self.getFilePathForDirectory(directory: Directories.recorded.rawValue,
                                            fileName: fileName,
                                            accountID: accountID,
                                            conversationID: conversationID)
    }

    // MARK: DataTransferAdapter

    fileprivate func dataTransferIdList() -> [UInt64]? {
        return self.dataTransferAdapter.dataTransferList() as? [UInt64]
    }

    fileprivate func sendFile(withId transferId: inout UInt64, withInfo info: NSDataTransferInfo) -> NSDataTransferError {
        var err: NSDataTransferError = .unknown
        let _id = UnsafeMutablePointer<UInt64>.allocate(capacity: 1)
        err = self.dataTransferAdapter.sendFile(with: info, withTransferId: _id)
        transferId = _id.pointee
        return err
    }

    fileprivate func acceptFileTransfer(withId transferId: UInt64, withPath filePath: String, withOffset offset: Int64 = 0) -> NSDataTransferError {
        return self.dataTransferAdapter.acceptFileTransfer(withId: transferId, withFilePath: filePath, withOffset: offset)
    }

    fileprivate func cancelDataTransfer(withId transferId: UInt64) -> NSDataTransferError {
        return self.dataTransferAdapter.cancelDataTransfer(withId: transferId)
    }

    fileprivate func dataTransferInfo(withId transferId: UInt64, withInfo info: inout NSDataTransferInfo) -> NSDataTransferError {
        return self.dataTransferAdapter.dataTransferInfo(withId: transferId, with: info)
    }

    fileprivate func dataTransferBytesProgress(withId transferId: UInt64, withTotal total: inout Int64, withProgress progress: inout Int64) -> NSDataTransferError {
        var err: NSDataTransferError = .unknown
        let _total = UnsafeMutablePointer<Int64>.allocate(capacity: 1)
        let _progress = UnsafeMutablePointer<Int64>.allocate(capacity: 1)
        err = self.dataTransferAdapter.dataTransferBytesProgress(withId: transferId, withTotal: _total, withProgress: _progress)
        total = _total.pointee
        progress = _progress.pointee
        return err
    }

    // MARK: DataTransferAdapterDelegate

    func dataTransferEvent(withTransferId transferId: UInt64, withEventCode eventCode: Int) {
        guard let event = NSDataTransferEventCode(rawValue: UInt32(eventCode)) else {
            self.log.error("DataTransferService: can't get transfer code")
            return
        }

        self.log.info("DataTransferService: event: \(stringFromEventCode(with: event))")
        let info = getTransferInfo(withId: transferId)
        // do not emit an created event for outgoing transfer, since it already saved in db
        if event == .created && info?.flags != 1 {
          return
        }
        // we aggregate all non-create type transfer events into the update category
        // emit service event
        let serviceEventType: ServiceEventType = event == .created ? .dataTransferCreated : .dataTransferChanged
        var serviceEvent = ServiceEvent(withEventType: serviceEventType)
        serviceEvent.addEventInput(.transferId, value: transferId)
        self.responseStream.onNext(serviceEvent)
    }

}
