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

import RxSwift
import UIKit

class ConferenceLayout: UIView {
    @IBOutlet private var conferenceLayoutWidthConstraint: NSLayoutConstraint!
    @IBOutlet private var conferenceLayoutHeightConstraint: NSLayoutConstraint!
    private var participants: [ConferenceParticipant] = .init()
    private let textSize: CGFloat = 16
    private let labelHight: CGFloat = 30
    private let controlSize: CGFloat = 25
    private let margin: CGFloat = 15
    private let minWidth: CGFloat = 50
    private let conferenceLayoutHelper: ConferenceLayoutHelper = .init()
    private var isCurrentModerator: Bool = false
    private let disposeBag = DisposeBag()

    func setUpWithVideoSize(size: CGSize) {
        conferenceLayoutHelper.setVideoSize(size: size)
        NotificationCenter.default.rx
            .notification(UIDevice.orientationDidChangeNotification)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in
                guard UIDevice.current.portraitOrLandscape else { return }
                self?.updateViewSize()
                self?.layoutParticipantsViews()
            })
            .disposed(by: disposeBag)
        updateViewSize()
    }

    func setParticipants(participants: [ConferenceParticipant]?, isCurrentModerator: Bool) {
        if let participants = participants {
            self.participants = participants
        } else {
            self.participants.removeAll()
        }
        self.isCurrentModerator = isCurrentModerator
        layoutParticipantsViews()
    }

    private func updateViewSize() {
        let width = conferenceLayoutHelper.getWidthConstraint()
        let height = conferenceLayoutHelper.getHeightConstraint()
        conferenceLayoutHeightConstraint.constant = height
        conferenceLayoutWidthConstraint.constant = width
    }

    private func layoutParticipantsViews() {
        removeSubviews(recursive: true)
        addParticipantsViews()
    }

    private func addParticipantsViews() {
        for participant in participants where participant.width != 0 && participant.height != 0 {
            self.addViewFor(participant: participant)
        }
    }

    private func addViewFor(participant: ConferenceParticipant) {
        guard let uri = participant.uri else { return }
        let displayName = participant.displayName.isEmpty ? uri : participant.displayName
        let widthRatio = conferenceLayoutHelper.getWidthRatio()
        let heightRatio = conferenceLayoutHelper.getHeightRatio()
        let origX: CGFloat = participant.originX * widthRatio
        let origY: CGFloat = participant.originY * heightRatio
        let width: CGFloat = participant.width * widthRatio
        let height: CGFloat = participant.height * heightRatio
        // do not add labels when view width is too small
        if width < minWidth { return }
        let background = UIView(frame: CGRect(x: origX, y: origY, width: width, height: labelHight))
        background.applyGradient(
            with: [UIColor(red: 0, green: 0, blue: 0, alpha: 0.6), UIColor(
                red: 0,
                green: 0,
                blue: 0,
                alpha: 0
            )],
            gradient: .vertical
        )
        var labelFrame = background.frame
        labelFrame.origin.x += (margin * widthRatio)
        labelFrame.size.width -= (margin * 2 * widthRatio)
        let label = UILabel(frame: labelFrame)
        label.text = displayName.filterOutHost()
        label.textColor = UIColor.white
        label.textAlignment = .center
        label.font = label.font.withSize(textSize)
        addSubview(background)
        addSubview(label)
        if !participant.isHandRaised || !isCurrentModerator {
            return
        }
        let raisedHandImage = UIButton(frame: CGRect(
            x: origX + width - controlSize,
            y: origY + height - controlSize,
            width: controlSize,
            height: controlSize
        ))
        let image = UIImage(asset: Asset.raiseHand)?.withRenderingMode(.alwaysTemplate)
        raisedHandImage.setImage(image, for: .normal)
        raisedHandImage.tintColor = UIColor.white
        raisedHandImage.backgroundColor = UIColor.conferenceRaiseHand
        raisedHandImage.layer.cornerRadius = 4
        raisedHandImage.layer.maskedCorners = [.layerMinXMinYCorner]
        addSubview(raisedHandImage)
    }
}
