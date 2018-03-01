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

enum DataTransferStatus {
    // --->
}

public final class DataTransferService: DataTransferAdapterDelegate {

    private let log = SwiftyBeaver.self

    fileprivate let dataTransferAdapter: DataTransferAdapter
    fileprivate var transfers = Variable([DataTransferModel]())

    fileprivate let disposeBag = DisposeBag()
    fileprivate let responseStream = PublishSubject<ServiceEvent>()
    var sharedResponseStream: Observable<ServiceEvent>

    lazy var transfersObservable = {
        return self.transfers.asObservable()
    }()

    init(withDataTransferAdapter dataTransferAdapter: DataTransferAdapter) {
        self.responseStream.disposed(by: disposeBag)
        self.sharedResponseStream = responseStream.share()
        self.dataTransferAdapter = dataTransferAdapter
        DataTransferAdapter.delegate = self
    }

    // MARK: public

    func transfer(withTransferId transferId: UInt64) -> DataTransferModel? {
        guard let transfer = self.transfers.value.filter({ $0.id == transferId }).first else {
            return nil
        }
        return transfer
    }

    func acceptTransfer(withId transferId: UInt64) {
        guard let info = getTransferInfo(withId: transferId) else {
            return
        }
        // accept transfer
        if let pathUrl = getFilePathForTransfer(forFile: info.displayName) {
            self.log.debug("DataTransferService: saving file to: \(pathUrl.path))")
            _ = acceptFileTransfer(withId: transferId, withPath: pathUrl.path)
        } else {
            self.log.error("DataTransferService: saving file error: bad local path")
        }
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

    // MARK: private

    fileprivate func createTransfer(withId transferId: UInt64) -> Completable {
        return Completable.create(subscribe: { [unowned self] completable in
            // make sure a transfer with that id doesn't already exist
            if self.transfer(withTransferId: transferId) != nil {
                self.log.warning("DataTransferService: ignoring create transfer: transfer with id: \(transferId) already exists")
                completable(.error(DataTransferServiceError.createTransferError))
                return Disposables.create { }
            }
            guard let info = self.getTransferInfo(withId: transferId) else {
                completable(.error(DataTransferServiceError.createTransferError))
                return Disposables.create { }
            }
            // add to transfer list
            let newTransfer = DataTransferModel(withTransferId: transferId, withInfo: info)
            self.transfers.value.append(newTransfer)
            completable(.completed)
            return Disposables.create { }
        })
    }

    fileprivate func updateTransfer(withId transferId: UInt64) -> Completable {
        return Completable.create(subscribe: { [unowned self] completable in
            guard let info = self.getTransferInfo(withId: transferId) else {
                completable(.error(DataTransferServiceError.updateTransferError))
                return Disposables.create { }
            }
            guard let transfer = self.transfer(withTransferId: transferId) else {
                self.log.warning("DataTransferService: can't find transfer with id: \(transferId)")
                completable(.error(DataTransferServiceError.updateTransferError))
                return Disposables.create { }
            }
            transfer.update(withInfo: info)
            completable(.completed)
            return Disposables.create { }
        })
    }

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

    fileprivate func getTransferInfo(withId transferId: UInt64) -> NSDataTransferInfo? {
        let info = NSDataTransferInfo()
        let err = self.dataTransferAdapter.dataTransferInfo(withId: transferId, with: info)
        if err != .success {
            self.log.error("DataTransferService: error getting transfer info for id: \(transferId)")
            return nil
        }
        return info
    }

    fileprivate func removeTransfer(withId transferId: UInt64) {
        transfers.value = transfers.value.filter { $0.id != transferId }
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

        // we aggregate all non-create type transfer events into the update category
        if event == .finished {
            return removeTransfer(withId: transferId)
        }

        // we aggregate all non-create type transfer events into the update category
        let transferEvent = event == .created ? createTransfer(withId: transferId) : updateTransfer(withId: transferId)
        transferEvent
            .subscribe(onCompleted: {
                // emit service event
                let serviceEventType: ServiceEventType = event == .created ? .dataTransferCreated : .dataTransferChanged
                var serviceEvent = ServiceEvent(withEventType: serviceEventType)
                serviceEvent.addEventInput(.transferId, value: transferId)
                self.responseStream.onNext(serviceEvent)
            }, onError: { error in
                self.log.error("DataTransferService: event error: \(error)")
            })
            .disposed(by: self.disposeBag)
    }

}
