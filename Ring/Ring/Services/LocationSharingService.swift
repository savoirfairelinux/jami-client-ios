/*
*  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
*
*  Author: Raphaël Brulé <raphael.brule@savoirfairelinux.com>
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

import RxSwift
import RxCocoa
import SwiftyBeaver

class LocationSharingService {

    private let log = SwiftyBeaver.self

    private let conversationService: ConversationsService

    private let disposeBag = DisposeBag()
    private let locationManager = CLLocationManager()

    //let dbManager: DBManager

    private let _currentLocation = BehaviorRelay<CLLocationCoordinate2D?>(value: nil)
    var currentLocation: Observable<CLLocationCoordinate2D?> { _currentLocation.asObservable() }

    private var isSharingWithRecipientUri: [String: Bool] = [:]
    private var senderAccount: AccountModel?

    init(withConversationService conversationService: ConversationsService) {
        self.conversationService = conversationService
    }

    // TODO: with?
    func startSharingLocation(from senderAccount: AccountModel, to recipientUri: String) {
        self.senderAccount = senderAccount

        self.isSharingWithRecipientUri[recipientUri] = true

        self.doShareLocationAction()

        Observable<Int>.interval(10.0, scheduler: MainScheduler.instance)
//            .takeUntil(self.isNotSharingLocation)
            .subscribe({ [weak self] elapsed in
                // TODO: improve this
                guard let self = self else { return }
                self.log.debug("Every 10 seconds: \(elapsed)")

                self.doShareLocationAction()
            })
            .disposed(by: self.disposeBag)
    }

    private func doShareLocationAction() {
        guard let location = self.locationManager.location, let jsonLocation = LocationSharingService.convertLocationToJSON(location: location) else { return }

        self._currentLocation.accept(location.coordinate)

        for (keyValue) in isSharingWithRecipientUri where keyValue.value {
            self.conversationService
                .sendLocation(withContent: jsonLocation,
                              from: self.senderAccount!,
                              recipientUri: keyValue.key)
                .subscribe(onCompleted: { [weak self] in
                    self?.log.debug("Location sent")
                }).disposed(by: self.disposeBag)
        }
    }

    private static func convertLocationToJSON(location: CLLocation) -> String? {
        let sLocation = SerializableLocation(lat: location.coordinate.latitude, long: location.coordinate.longitude, alt: location.altitude, time: 0)

        do {
            let data = try JSONEncoder().encode(sLocation)
            return String(data: data, encoding: .utf8)!
        } catch {
            return nil
        }
    }
}

struct SerializableLocation: Codable {
    var lat: Double
    var long: Double
    var alt: Double
    var time: Int64
}

//extension LocationSharingService: MaplyLocationTrackerDelegate {
//    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
//        self.log.error(error.localizedDescription)
//    }
//
//    func locationManager(_ manager: CLLocationManager, didChange status: CLAuthorizationStatus) {
//        self.log.debug("[MaplyLocationTrackerDelegate] didChange \(status.rawValue)")
//    }
//}
