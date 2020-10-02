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

import UIKit
import RxSwift

class ConferenceLayout: UIView {
    @IBOutlet private weak var conferenceLayoutWidthConstraint: NSLayoutConstraint!
    @IBOutlet private weak var conferenceLayoutHeightConstraint: NSLayoutConstraint!
    private var participants: [ConferenceParticipant] = [ConferenceParticipant]()
    private let textSize: CGFloat = 16
    private let labelHight: CGFloat = 30
    private let margin: CGFloat = 15
    private let minWidth: CGFloat = 50
    private let conferenceLayoutHelper: ConferenceLayoutHelper = ConferenceLayoutHelper()
    private let disposeBag = DisposeBag()

    func setUpWithVideoSize(size: CGSize) {
        self.conferenceLayoutHelper.setVideoSize(size: size)
        NotificationCenter.default.rx
            .notification(UIDevice.orientationDidChangeNotification)
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: {[weak self] (_) in
                guard UIDevice.current.orientation != .unknown,
                    UIDevice.current.orientation != .faceUp,
                    UIDevice.current.orientation != .faceDown else {
                        return
                }
                self?.updateViewSize()
                self?.layoutParticipantsViews()
            })
            .disposed(by: self.disposeBag)
        self.updateViewSize()
    }

    func setParticipants(participants: [ConferenceParticipant]?) {
        if let participants = participants {
            self.participants = participants
        } else {
            self.participants.removeAll()
        }
        self.layoutParticipantsViews()
    }

    private func updateViewSize() {
        let width = self.conferenceLayoutHelper.getWidthConstraint()
        let height = self.conferenceLayoutHelper.getHeightConstraint()
        self.conferenceLayoutHeightConstraint.constant = height
        self.conferenceLayoutWidthConstraint.constant = width
    }

    private func layoutParticipantsViews() {
        self.removeSubviews(recursive: true)
        self.addParticipantsViews()
    }

    private func addParticipantsViews() {
        for participant in self.participants where participant.width != 0 && participant.height != 0 {
            self.addViewFor(participant: participant)
        }
    }

    private func addViewFor(participant: ConferenceParticipant) {
        guard let uri = participant.uri else { return }
        let displayName = participant.displayName.isEmpty ? uri : participant.displayName
        let widthRatio = self.conferenceLayoutHelper.getWidthRatio()
        let heightRatio = self.conferenceLayoutHelper.getHeightRatio()
        let origX: CGFloat = participant.originX * widthRatio
        let origY: CGFloat = participant.originY * heightRatio
        let width: CGFloat = participant.width * widthRatio
        // do not add labels when view width is too small
        if width < minWidth { return }
        let background = UIView(frame: CGRect(x: origX, y: origY, width: width, height: self.labelHight))
        background.applyGradient(with: [UIColor(red: 0, green: 0, blue: 0, alpha: 0.6), UIColor(red: 0, green: 0, blue: 0, alpha: 0)], gradient: .vertical)
        var labelFrame = background.frame
        labelFrame.origin.x += (self.margin * widthRatio)
        labelFrame.size.width -= (self.margin * 2 * widthRatio)
        let label = UILabel(frame: labelFrame)
        label.text = displayName
        label.textColor = UIColor.white
        label.textAlignment = .center
        label.font = label.font.withSize(self.textSize)
        self.addSubview(background)
        self.addSubview(label)
    }
}
