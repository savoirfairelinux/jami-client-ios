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

    func conversationTimestamp() -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(self) {
            return messageTimeString()
        }
        if calendar.isDateInYesterday(self) {
            return Date.relativeDayFormatter.string(from: self)
        }
        if isWithinLastWeek(calendar: calendar) {
            return Date.weekdayFormatter.string(from: self)
        }
        if calendar.isDate(self, equalTo: Date(), toGranularity: .year) {
            return Date.listDayInCurrentYearFormatter.string(from: self)
        }
        return Date.listDayFormatter.string(from: self)
    }

    func conversationDayLabel() -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(self) || calendar.isDateInYesterday(self) {
            return Date.relativeDayFormatter.string(from: self)
        }
        if isWithinLastWeek(calendar: calendar) {
            return Date.weekdayFormatter.string(from: self)
        }
        if calendar.isDate(self, equalTo: Date(), toGranularity: .year) {
            return Date.dayInCurrentYearFormatter.string(from: self)
        }
        return Date.dayFormatter.string(from: self)
    }

    func messageTimeString() -> String {
        return formatted(date: .omitted, time: .shortened)
    }

    func messageFullDateString() -> String {
        return Date.fullDateFormatter.string(from: self)
    }

    private func isWithinLastWeek(calendar: Calendar) -> Bool {
        let today = calendar.startOfDay(for: Date())
        let day = calendar.startOfDay(for: self)
        guard let days = calendar.dateComponents([.day], from: day, to: today).day else { return false }
        return (2...6).contains(days)
    }

    private static func templateFormatter(_ template: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.formattingContext = .beginningOfSentence
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter
    }

    private static let relativeDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.formattingContext = .beginningOfSentence
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.doesRelativeDateFormatting = true
        return formatter
    }()

    private static let fullDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.formattingContext = .beginningOfSentence
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter
    }()

    private static let weekdayFormatter = templateFormatter("EEEE")
    private static let dayInCurrentYearFormatter = templateFormatter("EEEMMMd")
    private static let dayFormatter = templateFormatter("yMMMd")
    private static let listDayInCurrentYearFormatter = templateFormatter("MMMd")
    private static let listDayFormatter = templateFormatter("yyMd")
}
