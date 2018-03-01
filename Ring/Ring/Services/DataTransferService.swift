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

public final class DataTransferService: DataTransferAdapterDelegate {

    fileprivate let dataTransferAdapter: DataTransferAdapter

    private let log = SwiftyBeaver.self

    fileprivate let disposeBag = DisposeBag()

    init(withDataTransferAdapter dataTransferAdapter: DataTransferAdapter) {
        self.dataTransferAdapter = dataTransferAdapter
        DataTransferAdapter.delegate = self
    }

    // MARK: CallsAdapterDelegate

    func dataTransferEvent(withTransferId transferId: UInt64, withEventCode eventCode: Int) {
        let a: NSDataTransferError
        self.log.debug("dataTransferEvent")
    }

    func somefunc() -> NSDataTransferError {
        return NSDataTransferError.io
    }
}
