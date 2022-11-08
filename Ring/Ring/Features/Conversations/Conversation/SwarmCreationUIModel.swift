//
//  SwiftCreationUIModel.swift
//  Ring
//
//  Created by Binal Ahiya on 2022-11-16.
//  Copyright © 2022 Savoir-faire Linux. All rights reserved.
//

import Foundation

class SwarmCreationUIModel: ObservableObject, ViewModel {
    @Published var contactItems = [ParticipantList]()

    required init(with injectionBag: InjectionBag) {

    }

}
