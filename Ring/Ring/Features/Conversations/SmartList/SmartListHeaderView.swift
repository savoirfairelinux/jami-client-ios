/*
 *  Copyright (C) 2023 Savoir-faire Linux Inc.
 *
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
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

import RxSwift
import UIKit

class SmartListHeaderView: UIView {
    @IBOutlet var conversationsSegmentControl: UISegmentedControl!

    let conversationTitle = L10n.Smartlist.conversations
    let requestsTitle = L10n.Smartlist.invitations

    let horizontalPadding: CGFloat = 10.0
    let verticalPadding: CGFloat = 5.0
    let textFontSize: CGFloat = 14
    let numberFontSize: CGFloat = 10
    let disposeBag = DisposeBag()

    func setUnread(messages: Int, requests: Int) {
        if requests == 0 {
            conversationsSegmentControl.setImage(nil, forSegmentAt: 0)
            conversationsSegmentControl.setImage(nil, forSegmentAt: 1)
            conversationsSegmentControl.isHidden = true
            return
        }
        conversationsSegmentControl.isHidden = false
        let attributedMessages = createAttributedString(text: conversationTitle, number: messages)
        conversationsSegmentControl.setImage(
            getImageForSegment(attributedString: attributedMessages)?
                .withRenderingMode(.alwaysOriginal),
            forSegmentAt: 0
        )
        let attributedRequests = createAttributedString(text: requestsTitle, number: requests)
        conversationsSegmentControl.setImage(
            getImageForSegment(attributedString: attributedRequests)?
                .withRenderingMode(.alwaysOriginal),
            forSegmentAt: 1
        )
    }

    func createAttributedString(text: String, number: Int) -> NSMutableAttributedString {
        let baseString = "\(text)  "
        let font = UIFont.systemFont(ofSize: textFontSize)
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.label,
            .font: font
        ]

        let attributedString = NSMutableAttributedString(string: baseString, attributes: attributes)
        // Append the messages number
        if number > 0 {
            attributedString.append(roundedRectangleWithNumber(number))
        }

        return attributedString
    }

    func roundedRectangleWithNumber(_ number: Int) -> NSAttributedString {
        let numberString = "\(number)"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: numberFontSize, weight: .medium),
            .foregroundColor: UIColor.white
        ]
        let sizeOfString = numberString.size(withAttributes: attributes)
        let roundedRectSize = CGSize(
            width: sizeOfString.width + horizontalPadding,
            height: sizeOfString.height + verticalPadding
        )

        UIGraphicsBeginImageContextWithOptions(roundedRectSize, false, UIScreen.main.scale)

        let roundedRectPath = UIBezierPath(
            roundedRect: CGRect(origin: .zero, size: roundedRectSize),
            cornerRadius: roundedRectSize.height / 2
        )
        UIColor.jamiButtonDark.setFill()
        roundedRectPath.fill()

        let stringOrigin = CGPoint(
            x: (roundedRectSize.width - sizeOfString.width) / 2,
            y: (roundedRectSize.height - sizeOfString.height) / 2
        )
        numberString.draw(at: stringOrigin, withAttributes: attributes)

        let roundedRectImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        let attachment = NSTextAttachment()
        attachment.image = roundedRectImage

        attachment.bounds = CGRect(origin: CGPoint(x: 0, y: -3.5), size: roundedRectSize)

        return NSAttributedString(attachment: attachment)
    }

    func getImageForSegment(attributedString: NSAttributedString) -> UIImage? {
        let size = attributedString.size()
        let paddedSize = CGSize(
            width: size.width + horizontalPadding,
            height: size.height + verticalPadding
        )
        UIGraphicsBeginImageContextWithOptions(paddedSize, false, UIScreen.main.scale)

        let context = UIGraphicsGetCurrentContext()
        context?.setFillColor(UIColor.clear.cgColor)
        context?.fill(CGRect(origin: .zero, size: paddedSize))

        attributedString.draw(in: CGRect(
            origin: CGPoint(x: horizontalPadding * 0.5, y: verticalPadding * 0.5),
            size: size
        ))

        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return image
    }
}
