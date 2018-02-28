/*
 *  Copyright (C) 2018 Savoir-faire Linux Inc.
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
import Reusable
import RxSwift
import RxCocoa
import RxDataSources
import GSKStretchyHeaderView

class ContactViewController: UIViewController, StoryboardBased, ViewModelBased {

    var viewModel: ContactViewModel!
    @IBOutlet private weak var tableView: UITableView!
    private let disposeBag = DisposeBag()
    private let cellIdentifier = "ProfileInfoCell"
    private var stretchyHeader: ProfileHeaderView!
    let titleView = TitleView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))

    override func viewDidLoad() {
        self.addHeaderView()
        self.setUpTableView()
        self.setUpNavigationTitle()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UIApplication.shared.statusBarStyle = .default
        self.navigationController?.navigationBar.layer.shadowColor = UIColor.clear.cgColor
        self.navigationController?.navigationBar.setBackgroundImage(UIImage(), for: UIBarMetrics.default)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("contact controller presented")
    }

    func setUpNavigationTitle() {
        navigationItem.titleView = titleView
    }

    func addHeaderView() {
        guard let nibViews = Bundle.main.loadNibNamed("ProfileHeaderView",
                                                      owner: self,
                                                      options: nil) else {
                                                        return
        }
        guard let headerView = nibViews.first as? ProfileHeaderView else {
            return
        }
        self.stretchyHeader = headerView
        self.tableView.addSubview(self.stretchyHeader)
        self.tableView.delegate = self
        self.configureHeaderViewBinding()
    }

    func configureHeaderViewBinding() {

        // avatar
        Observable<(Data?, String)>.combineLatest(self.viewModel.profileImageData.asObservable(),
                                                  self.viewModel.userName.asObservable()) { profileImage, username in
                                                    return (profileImage, username)
            }
            .observeOn(MainScheduler.instance)
            .startWith((self.viewModel.profileImageData.value, self.viewModel.userName.value))
            .subscribe({ [weak self] profileData -> Void in
                self?.stretchyHeader.avatarView?.subviews.forEach({ $0.removeFromSuperview() })
                self?.stretchyHeader.avatarView?.addSubview(AvatarView(profileImageData: profileData.element?.0,
                                                                       username: (profileData.element?.1)!,
                                                                       size: 100))
                self?.titleView.avatarImage = AvatarView(profileImageData: profileData.element?.0,
                                                         username: (profileData.element?.1)!,
                                                         size: 36)
                return
            })
            .disposed(by: self.disposeBag)

        self.viewModel.userName.asDriver()
            .drive(self.stretchyHeader.userName!.rx.text)
            .disposed(by: self.disposeBag)
        self.viewModel.displayName.asDriver()
            .drive(self.stretchyHeader.displayName!.rx.text)
            .disposed(by: self.disposeBag)
        self.viewModel.userName.asObservable()
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] name in
            self?.titleView.text = name
        }).disposed(by: self.disposeBag)
    }

    func setUpTableView() {
        self.tableView.rowHeight = 60.0
        let configureCell: (TableViewSectionedDataSource, UITableView, IndexPath, SectionModel<String, ContactActions>.Item)
            -> UITableViewCell = {
                (dataSource: TableViewSectionedDataSource<SectionModel<String, ContactActions>>,
                tableView: UITableView,
                indexPath: IndexPath,
                conversationItem: SectionModel<String, ContactActions>.Item) in

                let model = dataSource.sectionModels
                if model[indexPath.section].model == self.cellIdentifier {
                    let cell = tableView.dequeueReusableCell(withIdentifier: self.cellIdentifier)
                    let image = UIImage(asset: conversationItem.image)
                    let tintedImage = image?.withRenderingMode(.alwaysTemplate)
                    cell?.imageView?.image = tintedImage
                    cell?.imageView?.tintColor = UIColor.ringSecondary
                    cell?.textLabel?.text = conversationItem.title
                    return cell!
                }
                return UITableViewCell()
        }

        let dataSource = RxTableViewSectionedReloadDataSource<SectionModel<String,
            ContactActions>>(configureCell: configureCell)

        self.viewModel.tableSection
            .observeOn(MainScheduler.instance)
            .bind(to: self.tableView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)

        self.tableView.rx.itemSelected
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] indexPath in
                if  self?.tableView.cellForRow(at: indexPath) != nil {
                    switch indexPath.row {
                    case 0:
                        self?.viewModel.startAudioCall()
                    case 1:
                        self?.viewModel.startCall()
                    case 2:
                        _ = self?.navigationController?.popViewController(animated: false)
                    case 3:
                        self?.showDeleteConversationConfirmation()
                    case 4:
                        self?.showBlockContactConfirmation()
                    default:
                        break
                    }
                    self?.tableView.deselectRow(at: indexPath, animated: true)
                }
            }).disposed(by: self.disposeBag)
    }

    private func showDeleteConversationConfirmation() {
        let alert = UIAlertController(title: L10n.Alerts.confirmDeleteConversationTitle, message: L10n.Alerts.confirmDeleteConversationFromContact, preferredStyle: .alert)
        let deleteAction = UIAlertAction(title: L10n.Actions.deleteAction, style: .destructive) { [weak self](_: UIAlertAction!) -> Void in
            self?.viewModel.deleteConversation()
        }
        let cancelAction = UIAlertAction(title: L10n.Actions.cancelAction, style: .default) { (_: UIAlertAction!) -> Void in }
        alert.addAction(deleteAction)
        alert.addAction(cancelAction)
        self.present(alert, animated: true, completion: nil)
    }

    private func showBlockContactConfirmation() {
        let alert = UIAlertController(title: L10n.Alerts.confirmBlockContactTitle, message: L10n.Alerts.confirmBlockContact, preferredStyle: .alert)
        let blockAction = UIAlertAction(title: L10n.Actions.blockAction, style: .destructive) { [weak self] (_: UIAlertAction!) -> Void in
            self?.viewModel.blockContact()
            _ = self?.navigationController?.popToRootViewController(animated: false)
        }
        let cancelAction = UIAlertAction(title: L10n.Actions.cancelAction, style: .default) { (_: UIAlertAction!) -> Void in }
        alert.addAction(blockAction)
        alert.addAction(cancelAction)
        self.present(alert, animated: true, completion: nil)
    }
}

extension ContactViewController: UITableViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let navigationHeight = self.navigationController?.navigationBar.bounds.height
        var size = self.view.bounds.size
        var titlViewThreshold: CGFloat = 0
        if let height = navigationHeight {
            size.height -= (height - 10)
            titlViewThreshold = height
        }
        if scrollView.contentSize.height < size.height {
            scrollView.contentSize = size
        }
        guard let titleView = navigationItem.titleView as? TitleView else { return }
        titleView.scrollViewDidScroll(scrollView, threshold: titlViewThreshold)
    }
}
