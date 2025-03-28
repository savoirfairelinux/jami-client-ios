/*
 *  Copyright (C) 2025-2025 Savoir-faire Linux Inc.
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

import XCTest
import RxSwift
import RxRelay
@testable import Ring

// MARK: - Test Constants

enum CallTestConstants {
    static let accountId = "test-account-id"
    static let callId = "test-call-id"
    static let invalidCallId = "invalid-call-id"
    static let profileUri = "test-uri"
    static let participantUri = "test-participant"
    static let displayName = "John Doe"
    static let registeredName = "john"
    static let messageContent = "test message"
}

// MARK: - MIME Types

enum TestMIMETypes {
    static let textPlain = "text/plain"
    static let vCard = "x-ring/ring.profile.vcard;"
}

// MARK: - Media Types

enum TestMediaTypes {
    static let audio = MediaAttributeValue.audio.rawValue
    static let video = MediaAttributeValue.video.rawValue
}

// MARK: - Call Model Extensions

extension CallModel {
    /// Creates a call model for testing with basic properties
    static func createTestCall(
        withCallId callId: String = CallTestConstants.callId,
        accountId: String = CallTestConstants.accountId,
        participantUri: String = CallTestConstants.participantUri,
        displayName: String = CallTestConstants.displayName,
        registeredName: String = CallTestConstants.registeredName
    ) -> CallModel {
        let call = CallModel()
        call.callId = callId
        call.accountId = accountId
        call.participantUri = participantUri
        call.displayName = displayName
        call.registeredName = registeredName
        return call
    }
}

// MARK: - Account Model Extensions

extension AccountModel {
    /// Creates an account model for testing with basic properties
    static func createTestAccount(withId id: String = CallTestConstants.accountId) -> AccountModel {
        let accountModel = AccountModel()
        accountModel.id = id

        let details: NSDictionary = [ConfigKey.accountUsername.rawValue: id]
        let accountDetailsDict = details as NSDictionary? as? [String: String] ?? nil
        let accountDetails = AccountConfigModel(withDetails: accountDetailsDict)

        accountModel.details = accountDetails
        return accountModel
    }
}

// MARK: - Profile Extensions

extension Profile {
    /// Creates a profile for testing with basic properties
    static func createTestProfile(withUri uri: String = CallTestConstants.profileUri) -> Profile {
        return Profile(uri: uri, type: "RING")
    }
}

// MARK: - Media Helpers

struct TestMediaFactory {
    /// Creates an audio media entry for testing
    static func createAudioMedia(
        label: String = "audio_0",
        muted: Bool = false,
        enabled: Bool = true
    ) -> [String: String] {
        return [
            MediaAttributeKey.mediaType.rawValue: TestMediaTypes.audio,
            MediaAttributeKey.label.rawValue: label,
            MediaAttributeKey.muted.rawValue: muted ? "true" : "false",
            MediaAttributeKey.enabled.rawValue: enabled ? "true" : "false"
        ]
    }

    /// Creates a video media entry for testing
    static func createVideoMedia(
        label: String = "video_0",
        muted: Bool = false,
        enabled: Bool = true,
        source: String = "camera"
    ) -> [String: String] {
        return [
            MediaAttributeKey.mediaType.rawValue: TestMediaTypes.video,
            MediaAttributeKey.label.rawValue: label,
            MediaAttributeKey.muted.rawValue: muted ? "true" : "false",
            MediaAttributeKey.enabled.rawValue: enabled ? "true" : "false",
            MediaAttributeKey.source.rawValue: source
        ]
    }
}
