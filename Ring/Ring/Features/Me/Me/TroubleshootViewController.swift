/*
 *  Copyright (C) 2021 Savoir-faire Linux Inc.
 *
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
 *  Author: Quentin Muret <quentin.muret@savoirfairelinux.com>
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
import Reusable
import RxSwift

class TroubleshootViewController: UIViewController, StoryboardBased, ViewModelBased {
    var viewModel: TroubleshootViewModel!
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var logSwitch: UISwitch!
    @IBOutlet weak var shareButton: UIButton!
    @IBOutlet weak var cleanButton: UIButton!
    let disposeBag = DisposeBag()

    override func viewDidLoad() {
        super.viewDidLoad()

        self.configureRingNavigationBar()
        self.navigationItem.title = "Troubleshoot"

        cleanButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.textView.text = ""
            })
            .disposed(by: self.disposeBag)

        shareButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.shareLog()
            })
            .disposed(by: self.disposeBag)

        logSwitch.rx
            .isOn.changed
            .debounce(Durations.switchThrottlingDuration.toTimeInterval(), scheduler: MainScheduler.instance)
            .distinctUntilChanged()
            .asObservable()
            .subscribe(onNext: {[weak self] enable in
                self?.viewModel.triggerLogging(enable: enable)
                if !enable {
                    self?.textView.text = ""
                }
            })
            .disposed(by: self.disposeBag)

        self.viewModel.debugMessageReceived
            .asObservable()
            .observe(on: MainScheduler.instance)
            .subscribe { message in
                self.textView.text.append(" " + message)
                let range = NSRange(location: self.textView.text.lengthOfBytes(using: .utf8), length: 0)
                self.textView.scrollRangeToVisible(range)
            } onError: { _ in
            }
            .disposed(by: disposeBag)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.logSwitch.setOn(false, animated: false)
    }

    func shareLog() {
        guard let text = self.textView.text else { return }
        let content = [text] as [Any]
        let title = ""
        let activityViewController = UIActivityViewController(activityItems: content,
                                                              applicationActivities: nil)
        activityViewController.setValue(title, forKey: "Subject")
        if UIDevice.current.userInterfaceIdiom == .phone {
            activityViewController.popoverPresentationController?.sourceView = self.view
        } else {
            activityViewController.popoverPresentationController?.sourceView = cleanButton
        }
        self.present(activityViewController, animated: true, completion: nil)
    }
}
