/*
 *  Copyright (C) 2023 Savoir-faire Linux Inc.
 *
 *  Author: Alireza Toghiani Khorasgani alireza.toghiani@savoirfairelinux.com *
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

class DurationPicker: UIPickerView, UIPickerViewDataSource, UIPickerViewDelegate {
    var hours: [Int] = []
    var minutes: [Int] = []
    var duration: Int = 0 {
        didSet {
            setupPickerWithDuration()
        }
    }

    let maxHours: Int
    weak var viewModel: GeneralSettingsViewModel!

    init(maxHours: Int, duration: Int) {
        self.maxHours = maxHours
        super.init(frame: .zero)

        for index in 0 ... maxHours {
            hours.append(index)
        }

        for index in 0 ... 59 {
            minutes.append(index)
        }

        dataSource = self
        delegate = self
        self.duration = duration
        setupPickerWithDuration()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func numberOfComponents(in _: UIPickerView) -> Int {
        return 2 // for hours and minutes
    }

    func pickerView(_: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        if component == 0 {
            return hours.count
        } else {
            return minutes.count
        }
    }

    func pickerView(_: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        if component == 0 {
            return "\(hours[row]) hours"
        } else {
            return "\(minutes[row]) minutes"
        }
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow _: Int, inComponent _: Int) {
        let hoursIndex = pickerView.selectedRow(inComponent: 0)
        let minutesIndex = pickerView.selectedRow(inComponent: 1)
        duration = hours[hoursIndex] * 60 + minutes[minutesIndex]
        if duration == 0 {
            pickerView.selectRow(1, inComponent: 1, animated: true)
            duration = 1
        }
        viewModel?.changeLocationSharingDuration(value: duration)
    }

    func setupPickerWithDuration() {
        let currentMinute = (duration % 60)
        let currentHour = (duration / 60)
        selectRow(currentHour, inComponent: 0, animated: false)
        selectRow(currentMinute, inComponent: 1, animated: false)
    }
}
