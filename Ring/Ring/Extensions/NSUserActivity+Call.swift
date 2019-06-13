//
//  NSUserActivity+Call.swift
//  Ring
//
//  Created by Kateryna Kostiuk on 2019-06-17.
//  Copyright © 2019 Savoir-faire Linux. All rights reserved.
//

import Foundation
import Intents
@available(iOS 10.0, *)
extension NSUserActivity {
    var startCallHandle: (uri: String, name: String, isVideo: Bool)? {
        guard let interaction = interaction else { return nil }
        let startVideoCallIntent = interaction.intent as? INStartVideoCallIntent
        let startAudioCallIntent = interaction.intent as? INStartAudioCallIntent
        if startVideoCallIntent == nil && startAudioCallIntent == nil {
            return nil
        }
        let isVideo = startVideoCallIntent != nil ? true : false
        if isVideo {
            guard
                let intent = startVideoCallIntent,
                let contact = intent.contacts?.first,
                let handle = contact.personHandle,
                let value = handle.value else {
                    return nil
            }
            return(value, contact.displayName, true)
        }
        guard
            let intent = startAudioCallIntent,
            let contact = intent.contacts?.first,
            let handle = contact.personHandle,
            let value = handle.value else {
                return nil
        }
        return(value, contact.displayName, false)
    }
}
