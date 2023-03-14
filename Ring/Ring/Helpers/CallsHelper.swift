//
//  CallsHelper.swift
//  Ring
//
//  Created by kateryna on 2023-03-15.
//  Copyright © 2023 Savoir-faire Linux. All rights reserved.
//

import UIKit
import CallKit

class CallsHelpers {
    class func providerConfiguration() -> CXProviderConfiguration {
        let providerConfiguration = CXProviderConfiguration()
        providerConfiguration.supportsVideo = true
        providerConfiguration.supportedHandleTypes = [.generic, .phoneNumber]
        providerConfiguration.ringtoneSound = "default.wav"
        providerConfiguration.iconTemplateImageData = UIImage(asset: Asset.jamiLogo)?.pngData()
        providerConfiguration.maximumCallGroups = 1
        providerConfiguration.maximumCallsPerCallGroup = 1
        return providerConfiguration
    }
}
