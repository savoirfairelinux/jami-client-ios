//
//  ShareInjectionBag.swift
//  ShareExtension
//
//  Created by Alireza Toghiani on 7/26/23.
//  Copyright © 2023 Savoir-faire Linux. All rights reserved.
//

import Foundation

/// We can centralize in this bag every service that is to be used by every layer of the app
class ShareInjectionBag {

    let daemonService: ShareAdapterService
    let nameService: ShareNameService

    init (withDaemonService daemonService: ShareAdapterService,
          nameService: ShareNameService) {
        self.daemonService = daemonService
        self.nameService = nameService
    }
}
