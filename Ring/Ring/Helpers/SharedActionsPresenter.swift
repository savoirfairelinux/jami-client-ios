/*
 *  Copyright (C) 2023-2025 Savoir-faire Linux Inc.
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

class SharedActionsPresenter {

    class func showAboutJamiAlert(onViewController viewController: UIViewController) {
        let fullVersion: String = Constants.fullVersion ?? ""

        let versionName = Constants.versionName
        let alert = UIAlertController(title: "\nJami\nversion: \(fullVersion)\n\(versionName)", message: "", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L10n.Global.ok, style: .default, handler: nil))
        let image = UIImageView(image: UIImage(asset: Asset.jamiIcon))
        alert.view.addSubview(image)
        image.translatesAutoresizingMaskIntoConstraints = false
        alert.view.addConstraint(NSLayoutConstraint(item: image, attribute: .centerX, relatedBy: .equal, toItem: alert.view, attribute: .centerX, multiplier: 1, constant: 0))
        alert.view.addConstraint(NSLayoutConstraint(item: image, attribute: .centerY, relatedBy: .equal, toItem: alert.view, attribute: .top, multiplier: 1, constant: 0.0))
        alert.view.addConstraint(NSLayoutConstraint(item: image, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 64.0))
        alert.view.addConstraint(NSLayoutConstraint(item: image, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 64.0))
        viewController.present(alert, animated: true, completion: nil)
    }

    class func shareAccountInfo(onViewController viewController: UIViewController, sourceView: UIView, content: [Any]) {
        let title = L10n.AccountPage.contactMeOnJamiTitle
        let activityViewController = UIActivityViewController(activityItems: content,
                                                              applicationActivities: nil)
        activityViewController.setValue(title, forKey: "Subject")
        activityViewController.modalPresentationStyle = .overFullScreen
        if let popoverController = activityViewController.popoverPresentationController {
            popoverController.sourceView = sourceView
            popoverController.permittedArrowDirections = []
        }
        viewController.present(activityViewController, animated: true, completion: nil)
    }

    class func openDonationLink() {
        if let url = URL(string: "https://jami.net/donate/") {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
    }
}
