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
    func conversationTimestamp() -> String {
        if Calendar.current.isDateInToday(self) {
            return messageTimeString()
        }
        return dayString(currentYear: Date.listDayInCurrentYearFormatter, otherYear: Date.listDayFormatter)
    }

    func conversationDayLabel() -> String {
        return dayString(currentYear: Date.dayInCurrentYearFormatter, otherYear: Date.dayFormatter)
    }

    func messageTimeString() -> String {
        return formatted(date: .omitted, time: .shortened)
    }

    func messageFullDateString() -> String {
        return Date.fullDateFormatter.string(from: self)
    }

    private func dayString(currentYear: DateFormatter, otherYear: DateFormatter) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(self) || calendar.isDateInYesterday(self) {
            return Date.relativeDayFormatter.string(from: self)
        }
        if isWithinLastWeek(calendar: calendar) {
            return Date.weekdayFormatter.string(from: self)
        }
        if calendar.isDate(self, equalTo: Date(), toGranularity: .year) {
            return currentYear.string(from: self)
        }
        return otherYear.string(from: self)
    }

    private func isWithinLastWeek(calendar: Calendar) -> Bool {
        let today = calendar.startOfDay(for: Date())
        let day = calendar.startOfDay(for: self)
        guard let days = calendar.dateComponents([.day], from: day, to: today).day else { return false }
        return (2...6).contains(days)
    }

    private static func makeFormatter(_ configure: (DateFormatter) -> Void) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.timeZone = .autoupdatingCurrent
        formatter.formattingContext = .beginningOfSentence
        configure(formatter)
        return formatter
    }

    private static func templateFormatter(_ template: String) -> DateFormatter {
        return makeFormatter { $0.setLocalizedDateFormatFromTemplate(template) }
    }

    private static let relativeDayFormatter = makeFormatter {
        $0.dateStyle = .medium
        $0.timeStyle = .none
        $0.doesRelativeDateFormatting = true
    }

    private static let fullDateFormatter = makeFormatter {
        $0.dateStyle = .full
        $0.timeStyle = .short
    }

    private static let weekdayFormatter = templateFormatter("EEEE")
    private static let dayInCurrentYearFormatter = templateFormatter("EEEMMMd")
    private static let dayFormatter = templateFormatter("yMMMd")
    private static let listDayInCurrentYearFormatter = templateFormatter("MMMd")
    private static let listDayFormatter = templateFormatter("yyMd")
}
