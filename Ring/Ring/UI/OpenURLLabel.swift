/*
*  Copyright (C) 2020 Savoir-faire Linux Inc.
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

class OpenURLLabel: UILabel, UITextViewDelegate {

    func removeURLHandler() {
        if let text = self.text {
            self.attributedText = NSAttributedString(string: text)
        }
    }

    func handleURLTap() {
        guard let attributedString = self.attributedText,
            let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue),
            let text = self.text else { return }
        let mutableString = NSMutableAttributedString()
        mutableString.append(attributedString)
        let matches = detector.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        for match in matches {
            guard let range = Range(match.range, in: text),
                let url = URL(string: String(text[range])) else { continue }
            mutableString.addAttribute(.link, value: url, range: match.range)
        }
        if matches.isEmpty { return }
        self.attributedText = mutableString
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        guard let touch = touches.first,
            let attributedString = self.attributedText else { return }

        let textStorage = NSTextStorage(attributedString: attributedString)

        let layoutManager = NSLayoutManager()

        let textContainer = NSTextContainer(size: CGSize.zero)
        textContainer.lineBreakMode = self.lineBreakMode
        textContainer.lineFragmentPadding = 0.0

        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)

        let labelSize = self.frame.size
        textContainer.size.width = labelSize.width

        let locationOfTouchInLabel = touch.location(in: self)

        let indexOfCharacter = layoutManager.characterIndex(for: locationOfTouchInLabel, in: textContainer, fractionOfDistanceBetweenInsertionPoints: nil)
        let attributes = attributedString.attributes(at: indexOfCharacter, effectiveRange: nil)

        guard let url = attributes[.link] as? URL else { return }
        let urlString = url.absoluteString.contains("http") ? url.absoluteString : "http://\(url.absoluteString)"
        guard let prefixedUrl = URL(string: urlString) else { return }
        UIApplication.shared.open(prefixedUrl, completionHandler: nil)
    }
}
