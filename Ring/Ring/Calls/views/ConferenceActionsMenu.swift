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

enum MenuItem {
    case name
    case hangup
    case minimize
    case maximize
    case setModerator
    case muteAudio
}

class ConferenceActionMenu: UIView {
    private let marginY: CGFloat = 20
    private let marginX: CGFloat = 20
    private let maxWidth: CGFloat = 160
    private let menuItemWidth: CGFloat = 80
    private let menuItemHight: CGFloat = 30
    private let textSize: CGFloat = 20
    private var hangUpButton: UIButton?
    private var maximizeButton: UIButton?
    private var minimizeButton: UIButton?
    private var setModeratorButton: UIButton?
    private var muteAudioButton: UIButton?
    private let disposeBag = DisposeBag()
    private var muteLabelText: String = ""
    private var moderatorLabelText: String = ""
    private var muteButtonEnabled: Bool = false
    private var hasSetMute: Bool = false

    func configureWith(items: [MenuItem], displayName: String, muteText: String, moderatorText: String, muteEnabled: Bool) {
        self.addDisplayName(displayName: displayName)
        muteLabelText = muteText
        moderatorLabelText = moderatorText
        muteButtonEnabled = muteEnabled
        let itemsWithoutName = items.filter { item in
            item != .name
        }
        if !itemsWithoutName.isEmpty {
        for index in 1...itemsWithoutName.count {
            let position: CGFloat = self.marginY * CGFloat((index + 1)) + menuItemHight * CGFloat(index)
            self.addItem(item: itemsWithoutName[index - 1], positionY: position)
        }
        }
        self.updateWidth()
        self.updateHeight()
        self.addBackground()
    }

    func addItem(item: MenuItem, positionY: CGFloat) {
        switch item {
        case .minimize:
            self.addMinimizeButton(positionY: positionY)
        case .maximize:
            self.addMaximizeButton(positionY: positionY)
        case .setModerator:
            self.addSetModeratorButton(positionY: positionY)
        case .muteAudio:
            self.addMuteAudioButton(positionY: positionY)
        case .hangup:
            self.addHangUpButton(positionY: positionY)
        case .name:
            break
        }
    }

    func addHangUpAction(hangup: @escaping (() -> Void)) {
        guard let button = hangUpButton else { return }
        button.rx.tap
            .subscribe(onNext: { hangup() })
            .disposed(by: self.disposeBag)
    }

    func addMaximizeAction(maximize: @escaping (() -> Void)) {
        guard let button = maximizeButton else { return }
        button.rx.tap
            .subscribe(onNext: { maximize() })
            .disposed(by: self.disposeBag)
    }

    func addMinimizeAction(minimize: @escaping (() -> Void)) {
        guard let button = minimizeButton else { return }
        button.rx.tap
            .subscribe(onNext: { minimize() })
            .disposed(by: self.disposeBag)
    }

    func addSetModeratorAction(setModerator: @escaping (() -> Void)) {
        guard let button = setModeratorButton else { return }
        button.rx.tap
            .subscribe(onNext: { setModerator() })
            .disposed(by: self.disposeBag)
    }

    func addMuteAction(mute: @escaping (() -> Void)) {
        guard let button = muteAudioButton else { return }
        button.rx.tap
            .subscribe(onNext: { mute() })
            .disposed(by: self.disposeBag)
    }

    private func addDisplayName(displayName: String) {
        let labelName = UILabel(frame: CGRect(x: marginX, y: marginY, width: menuItemWidth, height: menuItemHight))
        labelName.font = labelName.font.withSize(self.textSize)
        labelName.text = displayName
        labelName.sizeToFit()
        labelName.textAlignment = .center
        self.addSubview(labelName)
    }

    private func addBackground() {
        let blurView = UIBlurEffect(style: .light)
        let background = UIVisualEffectView(effect: blurView)
        background.frame = self.bounds
        background.cornerRadius = 10
        background.clipsToBounds = true
        self.addSubview(background)
        self.sendSubviewToBack(background)
    }

    private func addHangUpButton(positionY: CGFloat) {
        let hangUpLabel = UILabel(frame: CGRect(x: marginX, y: positionY, width: menuItemWidth, height: menuItemHight))
        hangUpLabel.font = hangUpLabel.font.withSize(self.textSize)
        hangUpLabel.text = L10n.Calls.haghUp
        hangUpLabel.sizeToFit()
        hangUpLabel.textAlignment = .center
        self.hangUpButton = UIButton(frame: hangUpLabel.frame)
        self.addSubview(hangUpLabel)
        self.addSubview(self.hangUpButton!)
    }

    private func addMaximizeButton(positionY: CGFloat) {
        let maximizeLabel = UILabel(frame: CGRect(x: marginX, y: positionY, width: menuItemWidth, height: menuItemHight))
        maximizeLabel.font = maximizeLabel.font.withSize(self.textSize)
        maximizeLabel.text = L10n.Calls.maximize
        maximizeLabel.sizeToFit()
        maximizeLabel.textAlignment = .center
        self.maximizeButton = UIButton(frame: maximizeLabel.frame)
        self.addSubview(maximizeLabel)
        self.addSubview(self.maximizeButton!)
    }

    private func addMinimizeButton(positionY: CGFloat) {
        let minimizeLabel = UILabel(frame: CGRect(x: marginX, y: positionY, width: menuItemWidth, height: menuItemHight))
        minimizeLabel.font = minimizeLabel.font.withSize(self.textSize)
        minimizeLabel.text = L10n.Calls.minimize
        minimizeLabel.sizeToFit()
        minimizeLabel.textAlignment = .center
        self.minimizeButton = UIButton(frame: minimizeLabel.frame)
        self.addSubview(minimizeLabel)
        self.addSubview(self.minimizeButton!)
    }

    private func addSetModeratorButton(positionY: CGFloat) {
        let setModeratotLabel = UILabel(frame: CGRect(x: marginX, y: positionY, width: menuItemWidth, height: menuItemHight))
        setModeratotLabel.font = setModeratotLabel.font.withSize(self.textSize)
        setModeratotLabel.text = moderatorLabelText
        setModeratotLabel.sizeToFit()
        setModeratotLabel.textAlignment = .center
        self.setModeratorButton = UIButton(frame: setModeratotLabel.frame)
        self.addSubview(setModeratotLabel)
        self.addSubview(self.setModeratorButton!)
    }

    private func addMuteAudioButton(positionY: CGFloat) {
        let muteAudioLabel = UILabel(frame: CGRect(x: marginX, y: positionY, width: menuItemWidth, height: menuItemHight))
        muteAudioLabel.font = muteAudioLabel.font.withSize(self.textSize)
        muteAudioLabel.text = muteLabelText
        muteAudioLabel.sizeToFit()
        muteAudioLabel.textAlignment = .center
        if #available(iOS 13.0, *) {
            muteAudioLabel.textColor = muteButtonEnabled ? UIColor.label : UIColor.quaternaryLabel
        } else {
            muteAudioLabel.textColor = muteButtonEnabled ? UIColor.white : UIColor.lightText
        }
        self.addSubview(muteAudioLabel)
        if !muteButtonEnabled { return }
        self.muteAudioButton = UIButton(frame: muteAudioLabel.frame)
        self.addSubview(self.muteAudioButton!)
    }

    private func updateHeight() {
        var numberOfLabels: CGFloat = 0
        self.subviews.forEach { (childView) in
            guard childView is UILabel else { return }
            numberOfLabels += 1
        }
        var totalHeight: CGFloat = numberOfLabels * self.menuItemHight
        let margins: CGFloat = numberOfLabels == 0 ? CGFloat(0) : (numberOfLabels + 1) * marginY
        totalHeight += margins
        self.frame.size.height = totalHeight
    }

    private func updateWidth() {
        var totalWidth: CGFloat = 0
        self.subviews.forEach { (childView) in
            guard let labelView = childView as? UILabel else { return }
            totalWidth = max(totalWidth, labelView.frame.size.width)
        }
        let margins: CGFloat = self.subviews.isEmpty ? CGFloat(0) : CGFloat(marginX * 2)
        let finalWidth = min(totalWidth, maxWidth)
        self.frame.size.width = finalWidth + margins
        self.subviews.forEach { (childView) in
            childView.frame.size.width = finalWidth
        }
    }
}
