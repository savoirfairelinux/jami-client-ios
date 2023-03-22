//
//  DurationPicker.swift
//  Ring
//
//  Created by Alireza Toghiani on 3/29/23.
//  Copyright © 2023 Savoir-faire Linux. All rights reserved.
//

import Foundation

class DurationPicker: UIPickerView, UIPickerViewDataSource, UIPickerViewDelegate {
    var hours: [Int] = []
    var minutes: [Int] = []
    var duration: Int = 0
    let maxHours: Int
    weak var viewModel: GeneralSettingsViewModel!

    init(maxHours: Int, duration: Int) {
        self.maxHours = maxHours
        super.init(frame: .zero)

        for index in 0...maxHours {
            hours.append(index)
        }

        for index in 0...59 {
            minutes.append(index)
        }

        self.dataSource = self
        self.delegate = self

        let currentMinute = (duration % 60)
        let currentHour = (duration / 60)
        self.selectRow(currentHour, inComponent: 0, animated: false)
        self.selectRow(currentMinute, inComponent: 1, animated: false)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 2 // for hours and minutes
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        if component == 0 {
            return hours.count
        } else {
            return minutes.count
        }
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        if component == 0 {
            return "\(hours[row]) hours"
        } else {
            return "\(minutes[row]) minutes"
        }
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        let hoursIndex = pickerView.selectedRow(inComponent: 0)
        let minutesIndex = pickerView.selectedRow(inComponent: 1)
        duration = hours[hoursIndex] * 60 + minutes[minutesIndex]
        viewModel?.changeLocationSharingDuration(value: duration)
    }
}
