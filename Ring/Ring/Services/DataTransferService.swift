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
    case conversation_data
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

/*
Manage sent and received files

files stored in next locations:
- non swarm:
   sent/received file: /.../AppData/Documents/downloads/accountId/conversationId/fileName
   recorded file: /.../AppData/Documents/recorded/accountId/conversationId/fileName
- swarm:  /.../AppData/Documents/accountId/conversation_data/conversationId/fileName. For received files it default path for demon. For sent files we need to save file to this direction
 */
public final class DataTransferService: DataTransferAdapterDelegate {

    private let log = SwiftyBeaver.self

    // contain image if transfering file is image type, othewise contain nil
    typealias ImageTuple = (isImage: Bool, data: UIImage?)
    private var transferedImages = [String: ImageTuple]()

    private let dataTransferAdapter: DataTransferAdapter

    private let disposeBag = DisposeBag()
    private let responseStream = PublishSubject<ServiceEvent>()
    var sharedResponseStream: Observable<ServiceEvent>
    let dbManager: DBManager

    init(withDataTransferAdapter dataTransferAdapter: DataTransferAdapter, dbManager: DBManager) {
        self.responseStream.disposed(by: disposeBag)
        self.sharedResponseStream = responseStream.share()
        self.dataTransferAdapter = dataTransferAdapter
        self.dbManager = dbManager
        DataTransferAdapter.delegate = self
    }

    // MARK: transfer info

    func dataTransferInfo(withId fileId: String, accountId: String, conversationId: String, isSwarm: Bool) -> NSDataTransferInfo? {
        let info = NSDataTransferInfo()
        var err: NSDataTransferError
        if !isSwarm {
            err = self.dataTransferAdapter.nonSwarmTransferInfo(withId: fileId, accountId: accountId, with: info)
        } else {
            info.conversationId = conversationId
            err = self.dataTransferAdapter.swarmTransferProgress(withId: fileId, accountId: accountId, with: info)
        }
        if err != .success {
            self.log.error("DataTransferService: error getting transfer info for id: \(fileId)")
            return nil
        }
        return info
    }

    func getTransferProgress(withId transferId: String, accountId: String, conversationId: String, isSwarm: Bool) -> Float? {
        guard let info = self.dataTransferInfo(withId: transferId, accountId: accountId, conversationId: conversationId, isSwarm: isSwarm) else {
            return nil }
        let progressValue = Float(info.bytesProgress) / Float(info.totalSize)
        return progressValue
    }

    // MARK: swarm transfer actions

    func downloadFile(withId transferId: String,
                      interactionID: String,
                      fileName: inout String,
                      accountID: String,
                      conversationID: String) {
        let path = ""
        self.dataTransferAdapter.downloadSwarmTransfer(withFileId: transferId, accountId: accountID, conversationId: conversationID, interactionId: interactionID, withFilePath: path)
    }

    // MARK: non swarm transfer actions

    func acceptTransfer(withId transferId: String,
                        fileName: inout String,
                        accountID: String,
                        conversationID: String,
                        name: String) -> NSDataTransferError {
        guard let info = dataTransferInfo(withId: String(transferId), accountId: accountID, conversationId: conversationID, isSwarm: false) else {
            return NSDataTransferError.invalid_argument
        }
        // accept transfer
        if let pathUrl = getFilePathForTransfer(forFile: info.displayName, accountID: accountID,
                                                conversationID: conversationID) {
            // if file name was changed because the same name already exist, update db
            if pathUrl.lastPathComponent != info.displayName {
                let fileSizeWithUnit = ByteCountFormatter.string(fromByteCount: Int64(info.totalSize), countStyle: .file)
                let name = pathUrl.lastPathComponent + "\n" + fileSizeWithUnit
                fileName = name
                // update db
                self.dbManager.updateFileName(daemonID: transferId, name: name, accountId: accountID)
                    .subscribe(onCompleted: { [weak self] in
                        self?.log.debug("file name updated")
                        }, onError: { [weak self] _ in
                            self?.log.error("update name failed")
                    })
                    .disposed(by: self.disposeBag)
            }
            self.log.debug("DataTransferService: saving file to: \(pathUrl.path))")
            return self.dataTransferAdapter.acceptNonSwarmTransfer(withId: transferId, accountId: accountID, withFilePath: pathUrl.path)
        } else {
            self.log.error("DataTransferService: saving file error: bad local path")
            return .io
        }
    }

    private func sendNonSwarmFile(filePath: String, displayName: String, accountId: String, peerInfoHash: String, localIdentifier: String?) {
        var transferId: UInt64 = 0
        let info = NSDataTransferInfo()
        info.accountId = accountId
        info.peer = peerInfoHash
        info.path = filePath
        info.mimetype = ""
        info.displayName = displayName
        let _id = UnsafeMutablePointer<UInt64>.allocate(capacity: 1)
        let err = self.dataTransferAdapter.sendNonSwarmFile(with: info, withTransferId: _id)
        transferId = _id.pointee
        if err != .success {
            self.log.error("sendFile failed")
        } else {
            let serviceEventType: ServiceEventType = .dataTransferCreated
            var serviceEvent = ServiceEvent(withEventType: serviceEventType)
            serviceEvent.addEventInput(.transferId, value: String(transferId))
            serviceEvent.addEventInput(.accountId, value: accountId)
            serviceEvent.addEventInput(.conversationId, value: "")
            serviceEvent.addEventInput(.messageId, value: "")
            if let localIdentifier = localIdentifier {
                serviceEvent.addEventInput(.localPhotolID, value: localIdentifier)
            }
            self.responseStream.onNext(serviceEvent)
        }
    }

    // MARK: swarm and non swarm transfer actions

    func cancelTransfer(withId transferId: String, accountId: String, conversationId: String) -> NSDataTransferError {
        let err = self.dataTransferAdapter.cancelDataTransfer(withId: transferId, accountId: accountId, conversationId: conversationId)
        if err != .success {
            self.log.error("couldn't cancel transfer with id: \(transferId)")
        }
        return err
    }

    func sendFile(conversation: ConversationModel, filePath: String, displayName: String, localIdentifier: String?) {
        if !conversation.isSwarm() {
            guard let jamiId = conversation.getParticipants().first?.jamiId else { return }
            self.sendNonSwarmFile(filePath: filePath, displayName: displayName, accountId: conversation.accountId, peerInfoHash: jamiId, localIdentifier: localIdentifier)
        } else {
            self.dataTransferAdapter.sendSwarmFile(withName: displayName,
                                                   accountId: conversation.accountId,
                                                   conversationId: conversation.id,
                                                   withFilePath: filePath,
                                                   parent: conversation.messages.value.last?.id)
        }
    }

    func sendAndSaveFile(displayName: String,
                         conversation: ConversationModel,
                         imageData: Data) {
        var fileUrl: URL?
        if !conversation.isSwarm() {
            fileUrl = self.getFilePathForTransfer(forFile: displayName, accountID: conversation.accountId, conversationID: conversation.id)
        } else {
            fileUrl = self.createFileUrlForSwarm(fileName: displayName, accountID: conversation.accountId, conversationID: conversation.id)
        }
        guard let imagePath = fileUrl else { return }
        do {
            try imageData.write(to: URL(fileURLWithPath: imagePath.path), options: .atomic)
        } catch {
            self.log.error("couldn't copy image to cache")
        }
        self.sendFile(conversation: conversation, filePath: imagePath.path, displayName: displayName, localIdentifier: nil)
    }

    // MARK: get image file

    /*
     to avoid creating images multiple time keep images in dictionary
     images saved in app document folder referenced by conversationId concatinated with image name
     images from photo librairy referenced by local identifier
    */

    func getImage(for name: String, maxSize: CGFloat, identifier: String? = nil,
                  accountID: String, conversationID: String, isSwarm: Bool) -> UIImage? {
        if let localImageIdentifier = identifier {
            if let image = self.transferedImages[localImageIdentifier] {
                return image.data
            }
            return self.getImageFromPhotoLibrairy(identifier: localImageIdentifier, maxSize: maxSize, name: name)
        }
        if let image = self.transferedImages[conversationID + name], let data = image.data {
            return data
        }
        return self.getImageFromFile(for: name, maxSize: maxSize, accountID: accountID,
                                     conversationID: conversationID, isSwarm: isSwarm)
    }

    private func getImageFromFile(for name: String,
                                  maxSize: CGFloat,
                                  accountID: String,
                                  conversationID: String,
                                  isSwarm: Bool) -> UIImage? {
        var fileUrl: URL?
        if isSwarm {
            fileUrl = self.getFileUrlForSwarm(fileName: name, accountID: accountID, conversationID: conversationID)
        } else {
            fileUrl = getFileUrlNonSwarm(fileName: name, inFolder: Directories.downloads.rawValue, accountID: accountID, conversationID: conversationID)
        }
        guard let pathUrl = fileUrl else { return nil }
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

    // MARK: get image from library. Only for non swarm conversations

    func getImageFromPhotoLibrairy(identifier: String, maxSize: CGFloat, name: String) -> UIImage? {
        let imageManager = PHImageManager.default()
        let requestOptions = PHImageRequestOptions()
        requestOptions.resizeMode = PHImageRequestOptionsResizeMode.exact
        requestOptions.isSynchronous = true
        var photo: UIImage?
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: PHFetchOptions()).firstObject else {
            return photo
        }
        imageManager.requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFit, options: requestOptions, resultHandler: {(result, _) -> Void in
            guard let image = result else { return }
            self.transferedImages[identifier] = (true, image)
            photo = image
        })
        return photo
    }

    func getFileURLFromPhotoLibrairy(identifier: String, completionHandler: @escaping (URL?) -> Void) -> Bool {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: PHFetchOptions()).firstObject else {
            return false
        }
        let option = PHContentEditingInputRequestOptions()
        asset.requestContentEditingInput(with: option) { contentEditingInput, _ in
            completionHandler(contentEditingInput?.fullSizeImageURL)
        }
        return true
    }

    // MARK: file path non swarm
    /// sent/received file: /.../AppData/Documents/downloads/accountId/conversationId/fileName
    /// recorded file: /.../AppData/Documents/recorded/accountId/conversationId/fileName

    /// get url for saved file for non swarm conversation. if file does not exists return nil
    func getFileUrlNonSwarm(fileName: String, inFolder: String, accountID: String, conversationID: String) -> URL? {
        guard let documentsURL = Constants.documentsPath else {
            return nil
        }
        let pathUrl = documentsURL.appendingPathComponent(inFolder)
            .appendingPathComponent(accountID)
            .appendingPathComponent(conversationID)
            .appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: pathUrl.path) {
            return pathUrl
        }
        return nil
    }

    /// create url to save file before sending for non swarm conversation
    private func createFileUrlForDirectory(directory: String, fileName: String, accountID: String, conversationID: String) -> URL? {
        let folderName = directory
        let fileNameOnly = (fileName as NSString).deletingPathExtension
        let fileExtensionOnly = (fileName as NSString).pathExtension
        var filePathUrl: URL?
        guard let documentsURL = Constants.documentsPath else {
            return nil
        }
        let directoryURL = documentsURL.appendingPathComponent(folderName)
            .appendingPathComponent(accountID)
            .appendingPathComponent(conversationID)
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

    private func getFilePathForTransfer(forFile fileName: String, accountID: String, conversationID: String) -> URL? {
        return self.createFileUrlForDirectory(directory: Directories.downloads.rawValue,
                                              fileName: fileName,
                                              accountID: accountID,
                                              conversationID: conversationID)
    }

    func getFilePathForRecordings(forFile fileName: String, accountID: String, conversationID: String, isSwarm: Bool) -> URL? {
        if isSwarm {
            return self.createFileUrlForSwarm(fileName: fileName, accountID: accountID, conversationID: conversationID)
        }
        return self.createFileUrlForDirectory(directory: Directories.recorded.rawValue,
                                              fileName: fileName,
                                              accountID: accountID,
                                              conversationID: conversationID)
    }

    // MARK: file path for swarm
    ///  /.../AppData/Documents/accountId/conversation_data/conversationId/fileName

    /// get url for saved file for swarm conversation. If file does not exists return nil
    func getFileUrlForSwarm(fileName: String, accountID: String, conversationID: String) -> URL? {
        guard let documentsURL = Constants.documentsPath else {
            return nil
        }
        let pathUrl = documentsURL.appendingPathComponent(accountID)
            .appendingPathComponent(Directories.conversation_data.rawValue)
            .appendingPathComponent(conversationID)
            .appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: pathUrl.path) {
            return pathUrl
        }
        return nil
    }

    /// create url to save file before sending for swarm conversation
    func createFileUrlForSwarm(fileName: String, accountID: String, conversationID: String) -> URL? {
        let fileNameOnly = (fileName as NSString).deletingPathExtension
        let fileExtensionOnly = (fileName as NSString).pathExtension
        guard let documentsURL = Constants.documentsPath else {
            return nil
        }
        let directoryURL = documentsURL.appendingPathComponent(accountID)
            .appendingPathComponent(Directories.conversation_data.rawValue)
            .appendingPathComponent(conversationID)
        var isDirectory = ObjCBool(false)
        let directoryExists = FileManager.default.fileExists(atPath: directoryURL.path, isDirectory: &isDirectory)
        if directoryExists && isDirectory.boolValue {
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
        return nil
    }

    func removeFile(at url: URL) {
        let fileManager = FileManager.default
        try? fileManager.removeItem(at: url)
    }

    // MARK: DataTransferAdapterDelegate

    func dataTransferEvent(withFileId transferId: String, withEventCode eventCode: Int, accountId: String, conversationId: String, interactionId: String) {
        guard let event = NSDataTransferEventCode(rawValue: UInt32(eventCode)) else {
            self.log.error("DataTransferService: can't get transfer code")
            return
        }

        self.log.info("DataTransferService: event: \(stringFromEventCode(with: event))")
        let isSwarm = !conversationId.isEmpty
        let info = dataTransferInfo(withId: transferId, accountId: accountId, conversationId: conversationId, isSwarm: isSwarm)
        /// do not emit an created event for outgoing transfer, since it already saved in db for non swarm conversation. For swarm conversation message created when interaction received
        if event == .created && info?.flags != 1 {
          return
        }
        /// we aggregate all non-create type transfer events into the update category
        /// emit service event
        let serviceEventType: ServiceEventType = event == .created ? .dataTransferCreated : .dataTransferChanged
        var serviceEvent = ServiceEvent(withEventType: serviceEventType)
        serviceEvent.addEventInput(.transferId, value: transferId)
        serviceEvent.addEventInput(.state, value: eventCode)
        serviceEvent.addEventInput(.conversationId, value: conversationId)
        serviceEvent.addEventInput(.messageId, value: interactionId)
        serviceEvent.addEventInput(.accountId, value: accountId)
        self.responseStream.onNext(serviceEvent)
    }

}
