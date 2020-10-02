/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
 *
 *  Author: Silbino Gonçalves Matado <silbino.gmatado@savoirfairelinux.com>
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

extension Date {
    func dayNumberOfWeek() -> Int? {
        return Calendar.current.dateComponents([.weekday], from: self).weekday
    }

    func dayOfWeek() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE"
        return dateFormatter.string(from: self)
    }

    static func convertSecondsToTimeString(seconds: Double) -> String {
        var string = ""
        var reminderSeconds = seconds
        let hours = Int(seconds / 3600)
        if hours > 0 {
            reminderSeconds = seconds.truncatingRemainder(dividingBy: 3600)
            string += String(format: "%02d", hours) + ":"

        }
        let min = Int(reminderSeconds / 60)
        let sec = reminderSeconds.truncatingRemainder(dividingBy: 60)
        string += String(format: "%02d:%02d", min, Int(sec))
        return string
    }

}
