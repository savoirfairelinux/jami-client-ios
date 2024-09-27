/*
 * Copyright (C) 2024 Savoir-faire Linux Inc. *
 *
 * Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version. *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details. *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

import Foundation
import RxSwift

class AboutSwiftUIVM {
    let declarationText = L10n.AboutJami.declaration1 + " [jami.net](https://jami.net) " + L10n.AboutJami.declaration2
    let noWarrantyText = L10n.AboutJami.noWarranty1 + " [NU General Public License](https://www.gnu.org/licenses/gpl-3.0.html), " + L10n.AboutJami.noWarranty2
    let mainUrlText = "© 2015-2024 [Savoir-Faire linux](https://savoirfairelinux.com)"
    let fullVersion: String = Constants.fullVersion ?? ""
    let contributeLabel: String = L10n.AboutJami.contribute
    let feedbackLabel: String = L10n.AboutJami.feedback
    let createdLabel: String = L10n.AboutJami.createdBy
    let artworkLabel: String = L10n.AboutJami.artworkBy

    func openContributeLink() {
        if let url = URL(string: "https://jami.net/contribute/") {
            UIApplication.shared.open(url)
        }
    }

    func sendFeedback() {
        if let url = mailtoURL(email: "jami@gnu.org",
                               subject: "Feedback for the Jami",
                               body: "Hello, I'd like to share some feedback...") {
            UIApplication.shared.open(url)
        }
    }

    func mailtoURL(email: String, subject: String, body: String) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = email
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]
        return components.url
    }

}
