/*
 *  Copyright (C) 2019 Savoir-faire Linux Inc.
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

import Reusable
import UIKit
import AVFoundation
import AudioToolbox
import RxSwift

class DialpadViewController: UIViewController, StoryboardBased, ViewModelBased {
    var viewModel: DialpadViewModel!

    var items = ["1", "2", "3", "4", "5", "6", "7", "8", "9", String("﹡"), "0", "#"]

    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var numberLabel: UILabel!
    @IBOutlet weak var placeCallButton: UIButton!
    @IBOutlet weak var backButton: UIButton!
    @IBOutlet weak var clearButton: UIButton!
    @IBOutlet weak var labelTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var labelBottomConstraint: NSLayoutConstraint!
    let disposeBag = DisposeBag()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.jamiBackgroundColor
        collectionView.backgroundColor = UIColor.jamiBackgroundColor
        self.applyL10n()
        let device = UIDevice.modelName
        if device == "iPhone 5" || device ==  "iPhone 5c" || device == "iPhone 5s" || device == "iPhone SE" {
            labelTopConstraint.constant = 15
            labelBottomConstraint.constant = 15
        }
        self.viewModel.observableNumber
            .asObservable()
            .observeOn(MainScheduler.instance)
            .bind(to: numberLabel.rx.text)
        .disposed(by: self.disposeBag)
        placeCallButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.dismiss(animated: false)
                self?.viewModel.startCall()
            })
            .disposed(by: self.disposeBag)
        backButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.dismiss(animated: true)
            })
            .disposed(by: self.disposeBag)
        clearButton.rx.tap
            .subscribe(onNext: { [weak self] in
                if self?.viewModel.phoneNumber.last != nil {
                    self?.viewModel.phoneNumber.removeLast()
                }
            }).disposed(by: self.disposeBag)
        self.viewModel.observableNumber
            .asObservable()
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { text in
                self.clearButton.isHidden = text.isEmpty
            }).disposed(by: self.disposeBag)
        self.viewModel.playDefaultSound
            .asObservable()
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { play in
                if !play {return}
                AudioServicesPlaySystemSound(1057)
            }).disposed(by: self.disposeBag)
        self.placeCallButton.isHidden = self.viewModel.inCallDialpad
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.collectionView
            .register(UICollectionViewCell.self,
                      forCellWithReuseIdentifier: "DialpadCellIdentifier")
    }

    func applyL10n() {
        self.backButton.setTitle(L10n.Actions.backAction, for: .normal)
        self.clearButton.setTitle(L10n.Actions.clearAction, for: .normal)
    }
}

extension DialpadViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

     func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 12
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "DialpadCellIdentifier", for: indexPath)
        let label: UILabel = cell.viewWithTag(200) as! UILabel
        label.text = self.items[indexPath.item]
        if label.text == String("﹡") {
            label.font = UIFont.systemFont(ofSize: 35, weight: .light)
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        self.viewModel.numberPressed(number: self.items[indexPath.item])
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = collectionView.frame.width/3
        return CGSize(width: width, height: 70)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 20
    }
}
