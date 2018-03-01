/*
 *  Copyright (C) 2018 Savoir-faire Linux Inc.
 *
 *  Author: Andreas Traczyk <andreas.traczyk@savoirfairelinux.com>
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
import SwiftyBeaver
import RxSwift

enum DataTransferServiceError: Error {
    case createTransferError
    case updateTransferError
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
    case .invalid: return L10n.Datatransfer.transferStatusInvalid
    case .created: return L10n.Datatransfer.transferStatusCreated
    case .unsupported: return L10n.Datatransfer.transferStatusUnsupported
    case .wait_host_acceptance: return L10n.Datatransfer.transferStatusWaitHostAcceptance
    case .wait_peer_acceptance: return L10n.Datatransfer.transferStatusWaitPeerAcceptance
    case .ongoing: return L10n.Datatransfer.transferStatusOngoing
    case .finished: return L10n.Datatransfer.transferStatusFinished
    case .closed_by_host: return L10n.Datatransfer.transferStatusClosedByHost
    case .closed_by_peer: return L10n.Datatransfer.transferStatusClosedByPeer
    case .invalid_pathname: return L10n.Datatransfer.transferStatusInvalidPathname
    case .unjoinable_peer: return L10n.Datatransfer.transferStatusUnjoinablePeer
    }
}
// swiftlint:enable cyclomatic_complexity

public final class DataTransferService: DataTransferAdapterDelegate {

    private let log = SwiftyBeaver.self

    fileprivate let dataTransferAdapter: DataTransferAdapter

    fileprivate let disposeBag = DisposeBag()
    fileprivate let responseStream = PublishSubject<ServiceEvent>()
    var sharedResponseStream: Observable<ServiceEvent>

    init(withDataTransferAdapter dataTransferAdapter: DataTransferAdapter) {
        self.responseStream.disposed(by: disposeBag)
        self.sharedResponseStream = responseStream.share()
        self.dataTransferAdapter = dataTransferAdapter
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

    func acceptTransfer(withId transferId: UInt64) -> NSDataTransferError {
        guard let info = getTransferInfo(withId: transferId) else {
            return NSDataTransferError.invalid_argument
        }
        // accept transfer
        if let pathUrl = getFilePathForTransfer(forFile: info.displayName) {
            self.log.debug("DataTransferService: saving file to: \(pathUrl.path))")
            return acceptFileTransfer(withId: transferId, withPath: pathUrl.path)
        } else {
            self.log.error("DataTransferService: saving file error: bad local path")
            return .io
        }
    }

    func cancelTransfer(withId transferId: UInt64) -> NSDataTransferError {
        let err = cancelDataTransfer(withId: transferId)
        if err != .success {
            self.log.error("couldn't cancel transfer with id: \(transferId)")
        }
        return err
    }

    func sendFile(filePath: String, displayName: String, accountId: String, peerInfoHash: String) {
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
        }
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

    fileprivate func getFilePathForTransfer(forFile fileName: String) -> URL? {
        let downloadsFolderName = "downloads"
        let fileNameOnly = (fileName as NSString).deletingPathExtension
        let fileExtensionOnly = (fileName as NSString).pathExtension
        var filePathUrl: URL?
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let directoryURL = documentsURL.appendingPathComponent(downloadsFolderName)
        var isDirectory = ObjCBool(false)
        let directoryExists = FileManager.default.fileExists(atPath: directoryURL.path, isDirectory: &isDirectory)
        if directoryExists && isDirectory.boolValue {
            // check if file exists, if so add " (<duplicates+1>)" or "_<duplicates+1>"
            // first check /.../AppData/Documents/downloads/<fileNameOnly>.<fileExtensionOnly>
            var finalFileName = fileNameOnly + "." + fileExtensionOnly
            var filePathCheck = directoryURL.appendingPathComponent(finalFileName)
            var fileExists = FileManager.default.fileExists(atPath: filePathCheck.path, isDirectory: &isDirectory)
            var duplicates = 2
            while fileExists {
                // check /.../AppData/Documents/downloads/<fileNameOnly>_<duplicates>.<fileExtensionOnly>
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
            filePathUrl = directoryURL.appendingPathComponent(fileName)
            return filePathUrl
        } catch _ as NSError {
            self.log.error("DataTransferService: error creating dir")
            return nil
        }
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

        // we aggregate all non-create type transfer events into the update category
        // emit service event
        let serviceEventType: ServiceEventType = event == .created ? .dataTransferCreated : .dataTransferChanged
        var serviceEvent = ServiceEvent(withEventType: serviceEventType)
        serviceEvent.addEventInput(.transferId, value: transferId)
        self.responseStream.onNext(serviceEvent)
    }

}
