/*
 *  Copyright (C) 2016-2019 Savoir-faire Linux Inc.
 *
 *  Author: Romain Bertozzi <romain.bertozzi@savoirfairelinux.com>
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

/**
 Events types that can be configured as identifier for the ServiceEvent.

 - AccountChanged: the accounts have been changed daemon-side
 - AccountAdded: an account has been added
 */
enum ServiceEventType {
    case accountAdded
    case accountsChanged
    case registrationStateChanged
    case presenceUpdated
    case messageStateChanged
    case knownDevicesChanged
    case exportOnRingEnded
    case contactAdded
    case contactRequestReceived
    case contactRequestDiscarded
    case proxyEnabled
    case notificationEnabled
    case callEnded
    case dataTransferCreated
    case dataTransferChanged
    case dataTransferMessageUpdated
    case deviceRevocationEnded
    case newIncomingMessage
    case nameRegistrationEnded
    case callProviderAnswerCall
    case callProviderCancellCall
    case audioActivated
    case newOutgoingMessage
    case messageTypingIndicator
    case migrationEnded
    case lastDisplayedMessageUpdated
    case presenseSubscribed
    case sendLocation
    case deleteLocation
    case stopLocationSharing
}

/**
 Keys that can be set as keys of the private input dictionary
 */
enum ServiceEventInput {
    case id
    case state
    case registrationState
    case uri
    case presenceStatus
    case messageStatus
    case messageId
    case pin
    case accountId
    case date
    case callType
    case callTime
    case transferId
    case localPhotolID
    case proxyAddress
    case deviceId
    case content
    case peerUri
    case accountUri
    case name
    case callUUID
    case oldDisplayedMessage
    case newDisplayedMessage
}

/**
 A struct representing an output of the services.
 Is meant to be used as stream events for example.
 Its responsabilities:
 - contain the information returned from the service
 */
struct ServiceEvent {
    // MARK: - Public members
    /**
     Identifies the event type.
     */
    internal fileprivate(set) var eventType: ServiceEventType

    // MARK: - Private members
    /**
     Contains all the metadata of the event.
     */
    fileprivate var inputs = [ServiceEventInput: Any]()

    /**
     Initializer
     */
    init(withEventType eventType: ServiceEventType) {
        self.eventType = eventType
    }

    // MARK: Core
    /**
     Allows to add an entry in the metadata of the event.
     */
    mutating func addEventInput<T>(_ input: ServiceEventInput, value: T) {
        inputs.updateValue(value, forKey: input)
    }

    /**
     Allows to get an entry of the metadata of the event.
     - Parameter input: the key of the data to find
     - Parameter T: the expected class of the data to get
     - Returns: the data casted in the correct T class, nil otherwise
     */
    func getEventInput<T>(_ input: ServiceEventInput) -> T? {
        let object = inputs[input]
        if let result = object as? T {
            return result
        }
        return nil
    }
}
