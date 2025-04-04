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

    func conversationTimestamp() -> String {
        var dateFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter
        }()
        var hourFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter
        }()
        let dateToday = Date()
        var dateString = ""
        let todayWeekOfYear = Calendar.current.component(.weekOfYear, from: dateToday)
        let todayDay = Calendar.current.component(.day, from: dateToday)
        let todayMonth = Calendar.current.component(.month, from: dateToday)
        let todayYear = Calendar.current.component(.year, from: dateToday)
        let weekOfYear = Calendar.current.component(.weekOfYear, from: self)
        let day = Calendar.current.component(.day, from: self)
        let month = Calendar.current.component(.month, from: self)
        let year = Calendar.current.component(.year, from: self)
        if todayDay == day && todayMonth == month && todayYear == year {
            dateString = hourFormatter.string(from: self)
        } else if day == todayDay - 1 {
            dateString = L10n.Smartlist.yesterday
        } else if todayYear == year && todayWeekOfYear == weekOfYear {
            dateString = self.dayOfWeek()
        } else {
            dateString = dateFormatter.string(from: self)
        }

        return dateString
    }

    func getTimeLabelString() -> String {
        let currentDateTime = Date()

        // prepare formatter
        let dateFormatter = DateFormatter()

        if Calendar.current.compare(currentDateTime, to: self, toGranularity: .day) == .orderedSame {
            // age: [0, received the previous day[
            dateFormatter.dateFormat = "h:mma"
        } else if Calendar.current.compare(currentDateTime, to: self, toGranularity: .weekOfYear) == .orderedSame {
            // age: [received the previous day, received 7 days ago[
            dateFormatter.dateFormat = "E h:mma"
        } else if Calendar.current.compare(currentDateTime, to: self, toGranularity: .year) == .orderedSame {
            // age: [received 7 days ago, received the previous year[
            dateFormatter.dateFormat = "MMM d, h:mma"
        } else {
            // age: [received the previous year, inf[
            dateFormatter.dateFormat = "MMM d, yyyy h:mma"
        }

        // generate the string containing the message time
        return dateFormatter.string(from: self).uppercased()
    }

}
