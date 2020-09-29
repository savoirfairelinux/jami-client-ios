//
//  ConferenceActionsMenu.swift
//  Ring
//
//  Created by kateryna on 2020-09-29.
//  Copyright © 2020 Savoir-faire Linux. All rights reserved.
//

import UIKit
import RxSwift

enum MenuItems {
    case displayName
    case hangUpCall
    case maximize
    case minimize
}

enum MenuMode {
    case withoutHangUp // for master call
    case withoutMaximize
    case withoutMinimize
    case withoutMaximizeAndMinimize
    case withoutHangUPAndMinimize
    case withoutHangUPAndMaximize
    case onlyName
    case all
}

class ConferenceActionMenu: UIView {
    private let marginY: CGFloat = 15
    private let marginX: CGFloat = 15
    private let maxWidth: CGFloat = 120
    private let menuItemWidth: CGFloat = 80
    private let menuItemHight: CGFloat = 20
    private var hangUpButton: UIButton?
    private var maximizeButton: UIButton?
    private var minimizeButton: UIButton?
    private let disposeBag = DisposeBag()

    func configureWith(mode: MenuMode, displayName: String) {
        self.addDisplayName(displayName: displayName)
        switch mode {
        case .withoutHangUp:
            self.configureWithoutHangUP()
        case .withoutMaximize:
            self.configureWithoutMaximize()
        case .withoutMinimize:
            self.configureWithoutMinimize()
        case .withoutMaximizeAndMinimize:
            self.configureWithoutMaximizeAndMinimize()
        case .withoutHangUPAndMinimize:
            self.configureWithoutHangUPAndMinimize()
        case .withoutHangUPAndMaximize:
            self.configureWithoutHangUPAndMaximize()
        case .all:
            self.configureWithAllItems()
        case .onlyName:
            break
        }
        self.updateWidth()
        self.updateHeight()
        self.addBackground()
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

    private func addDisplayName(displayName: String) {
        let labelName = UILabel(frame: CGRect(x: marginX, y: marginY, width: menuItemWidth, height: menuItemHight))
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
        hangUpLabel.text = L10n.Calls.haghUp
        hangUpLabel.sizeToFit()
        hangUpLabel.textAlignment = .center
        self.hangUpButton = UIButton(frame: hangUpLabel.frame)
        self.addSubview(hangUpLabel)
        self.addSubview(self.hangUpButton!)
    }

    private func addMaximizeButton(positionY: CGFloat) {
        let maximizeLabel = UILabel(frame: CGRect(x: marginX, y: positionY, width: menuItemWidth, height: menuItemHight))
        maximizeLabel.text = L10n.Calls.maximize
        maximizeLabel.sizeToFit()
        maximizeLabel.textAlignment = .center
        self.maximizeButton = UIButton(frame: maximizeLabel.frame)
        self.addSubview(maximizeLabel)
        self.addSubview(self.maximizeButton!)
    }

    private func addMinimizeButton(positionY: CGFloat) {
        let minimizeLabel = UILabel(frame: CGRect(x: marginX, y: positionY, width: menuItemWidth, height: menuItemHight))
        minimizeLabel.text = L10n.Calls.minimize
        minimizeLabel.sizeToFit()
        minimizeLabel.textAlignment = .center
        self.minimizeButton = UIButton(frame: minimizeLabel.frame)
        self.addSubview(minimizeLabel)
        self.addSubview(self.minimizeButton!)
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

    private func configureWithoutHangUP() {
        let firstY: CGFloat = CGFloat(self.marginY * 2 + menuItemHight)
        let secondY: CGFloat = CGFloat(self.marginY * 3 + menuItemHight * 2)
        self.addMaximizeButton(positionY: firstY)
        self.addMinimizeButton(positionY: secondY)
    }

    private func configureWithoutMaximize() {
        let firstY: CGFloat = CGFloat(self.marginY * 2 + menuItemHight)
        let secondY: CGFloat = CGFloat(self.marginY * 3 + menuItemHight * 2)
        self.addHangUpButton(positionY: firstY)
        self.addMinimizeButton(positionY: secondY)
    }

    private func configureWithoutMinimize() {
        let firstY: CGFloat = CGFloat(self.marginY * 2 + menuItemHight)
        let secondY: CGFloat = CGFloat(self.marginY * 3 + menuItemHight * 2)
        self.addHangUpButton(positionY: firstY)
        self.addMaximizeButton(positionY: secondY)
    }

    private func configureWithoutMaximizeAndMinimize() {
        let firstY: CGFloat = CGFloat(self.marginY * 2 + menuItemHight)
        self.addHangUpButton(positionY: firstY)
    }

    private func configureWithoutHangUPAndMinimize() {
        let firstY: CGFloat = CGFloat(self.marginY * 2 + menuItemHight)
        self.addMaximizeButton(positionY: firstY)
    }

    private func configureWithoutHangUPAndMaximize() {
        let firstY: CGFloat = CGFloat(self.marginY * 2 + menuItemHight)
        self.addMinimizeButton(positionY: firstY)
    }

    private func configureWithAllItems() {
        let firstY: CGFloat = CGFloat(self.marginY * 2 + menuItemHight)
        let secondY: CGFloat = CGFloat(self.marginY * 3 + menuItemHight * 2)
        let thirdtY: CGFloat = CGFloat(self.marginY * 4 + menuItemHight * 3)
        self.addHangUpButton(positionY: firstY)
        self.addMaximizeButton(positionY: secondY)
        self.addMinimizeButton(positionY: thirdtY)
    }
}
