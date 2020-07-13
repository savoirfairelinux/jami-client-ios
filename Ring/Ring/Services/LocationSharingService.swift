/*
*  Copyright (C) 2020 Savoir-faire Linux Inc.
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

struct SerializableLocation: Codable {
    var lat: Double
    var long: Double
    var alt: Double
    var time: Int64
}

class LocationSharingService {

    private let log = SwiftyBeaver.self

    private let conversationService: ConversationsService

    private let disposeBag = DisposeBag()
    private let locationManager = CLLocationManager()

    //let dbManager: DBManager

    // Sharing my location
    private let _currentLocation = BehaviorRelay<CLLocationCoordinate2D?>(value: nil)
    var currentLocation: Observable<CLLocationCoordinate2D?> { _currentLocation.asObservable() }

    private var isSendingWithRecipientUri: [String: Bool] = [:]

    // Receiving my contact's location
    private let _locationReceivedFromRecipientUri = BehaviorRelay<(String?, CLLocationCoordinate2D?)>(value: (nil, nil))
    var locationReceivedFromRecipientUri: Observable<(String?, CLLocationCoordinate2D?)> { _locationReceivedFromRecipientUri.asObservable() }

    init(withConversationService conversationService: ConversationsService) {
        self.conversationService = conversationService
    }

    private static func serializeLocation(location: CLLocation) -> String? {
        // TODO: time?
        let sLocation = SerializableLocation(lat: location.coordinate.latitude, long: location.coordinate.longitude, alt: location.altitude, time: 0)

        do {
            let data = try JSONEncoder().encode(sLocation)
            return String(data: data, encoding: .utf8)!
        } catch {
            return nil
        }
    }

    private static func deserializeLocation(json: String) -> CLLocationCoordinate2D? {
        do {
            // TODO: altitude and time?
            let sLocation = try JSONDecoder().decode(SerializableLocation.self, from: json.data(using: .utf8)!)
            return CLLocationCoordinate2D(latitude: sLocation.lat, longitude: sLocation.long)
        } catch {
            return nil
        }
    }
}

// MARK: Sharing my location
extension LocationSharingService {

    func startSharingLocation(from senderAccount: AccountModel, to recipientUri: String) {

        self.isSendingWithRecipientUri[recipientUri] = true

        self.doShareLocationAction(senderAccount)

        Observable<Int>.interval(10.0, scheduler: MainScheduler.instance)
            //.takeUntil(self.isNotSharingLocation)
            .subscribe({ [weak self] elapsed in
                // TODO: improve this
                guard let self = self else { return }
                self.log.debug("Every 10 seconds: \(elapsed)")

                self.doShareLocationAction(senderAccount)
            })
            .disposed(by: self.disposeBag)
    }

    private func doShareLocationAction(_ senderAccount: AccountModel) {
        guard let location = self.locationManager.location, let jsonLocation = LocationSharingService.serializeLocation(location: location) else { return }

        self._currentLocation.accept(location.coordinate)

        for (keyValue) in isSendingWithRecipientUri where keyValue.value {
            self.conversationService
                .sendLocation(withContent: jsonLocation,
                              from: senderAccount,
                              recipientUri: keyValue.key)
                .subscribe(onCompleted: { [weak self] in
                    self?.log.debug("Location sent")
                }).disposed(by: self.disposeBag)
        }
    }

    func stopSharingLocation(to recipientUri: String) {
        self.isSendingWithRecipientUri[recipientUri] = false
        self.log.debug("stopSharingLocation")
    }
}

// MARK: Receiving my contact's location
extension LocationSharingService {

    func handleReceivedLocationUpdate(from peerUri: String, to accountId: String, messageId: String, locationJSON content: String) {
        self.log.debug("handleReceivedLocationUpdate: \(content)")

        let value = (peerUri, LocationSharingService.deserializeLocation(json: content))
        self._locationReceivedFromRecipientUri.accept(value)
    }

}
