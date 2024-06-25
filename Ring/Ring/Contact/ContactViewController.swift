/*
 *  Copyright (C) 2018-2019 Savoir-faire Linux Inc.
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

import GSKStretchyHeaderView
import Reusable
import RxCocoa
import RxDataSources
import RxSwift
import UIKit

class ContactViewController: UIViewController, StoryboardBased, ViewModelBased {
    var viewModel: ContactViewModel!
    @IBOutlet private var tableView: UITableView!
    private let disposeBag = DisposeBag()
    private let cellIdentifier = "ProfileInfoCell"
    private var stretchyHeader: ProfileHeaderView!
    private let titleView = TitleView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))

    override func viewDidLoad() {
        super.viewDidLoad()
        addHeaderView()
        setUpTableView()
        view.backgroundColor = UIColor.jamiBackgroundColor
        tableView.backgroundColor = UIColor.jamiBackgroundColor
        navigationItem.titleView = titleView
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.layer.shadowColor = UIColor.clear.cgColor
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.navigationBar.layer.shadowColor = UIColor.jamiNavigationBarShadow
            .cgColor
    }

    private func addHeaderView() {
        guard let nibViews = Bundle.main.loadNibNamed("ProfileHeaderView",
                                                      owner: self,
                                                      options: nil)
        else {
            return
        }
        guard let headerView = nibViews.first as? ProfileHeaderView else {
            return
        }
        stretchyHeader = headerView
        tableView.addSubview(stretchyHeader)
        tableView.delegate = self
        configureHeaderViewBinding()
    }

    private func configureHeaderViewBinding() {
        // avatar
        Observable<(Data?, String)>.combineLatest(viewModel.profileImageData.asObservable(),
                                                  viewModel.displayName
                                                    .asObservable()) { profileImage, username in
            (profileImage, username)
        }
        .startWith((viewModel.profileImageData.value, viewModel.userName.value))
        .observe(on: MainScheduler.instance)
        .subscribe { [weak self] profileData in
            guard let data = profileData.element?.1 else { return }
            self?.stretchyHeader
                .avatarView?.subviews
                .forEach { $0.removeFromSuperview() }
            self?.stretchyHeader
                .avatarView?.addSubview(
                    AvatarView(profileImageData:
                                profileData.element?.0,
                               username: data,
                               size: 100,
                               labelFontSize: 44)
                )
            self?.titleView.avatarImage =
                AvatarView(profileImageData: profileData.element?.0,
                           username: data,
                           size: 36)
        }
        .disposed(by: disposeBag)

        let maxLabelWidth = UIScreen.main.bounds.size.width * 0.90
        stretchyHeader.jamiID.preferredMaxLayoutWidth = maxLabelWidth
        stretchyHeader.userName.preferredMaxLayoutWidth = maxLabelWidth
        stretchyHeader.displayName.preferredMaxLayoutWidth = maxLabelWidth

        viewModel.displayName.asDriver()
            .drive(stretchyHeader.displayName.rx.text)
            .disposed(by: disposeBag)

        viewModel.userName
            .observe(on: MainScheduler.instance)
            .asObservable()
            .subscribe(onNext: { username in
                if username != self.viewModel.conversation.hash {
                    self.stretchyHeader.userName.text = username
                }
            })
            .disposed(by: disposeBag)

        stretchyHeader.jamiID.text = viewModel.conversation.hash

        viewModel.titleName
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] name in
                self?.titleView.text = name
            })
            .disposed(by: disposeBag)
    }

    private func setUpTableView() {
        tableView.rowHeight = 60.0
        let configureCell: (
            TableViewSectionedDataSource,
            UITableView,
            IndexPath,
            SectionModel<String, ContactActions>.Item
        )
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
                cell?.imageView?.tintColor = UIColor.jamiSecondary
                cell?.textLabel?.text = conversationItem.title
                return cell!
            }
            return UITableViewCell()
        }

        let dataSource = RxTableViewSectionedReloadDataSource<SectionModel<
                                                                String,
                                                                ContactActions
                                                              >>(configureCell: configureCell)

        viewModel.tableSection
            .observe(on: MainScheduler.instance)
            .bind(to: tableView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)

        tableView.rx.itemSelected
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] indexPath in
                if self?.tableView.cellForRow(at: indexPath) != nil {
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
            })
            .disposed(by: disposeBag)
    }

    private func showDeleteConversationConfirmation() {
        let alert = UIAlertController(
            title: L10n.Alerts.confirmDeleteConversationTitle,
            message: L10n.Alerts.confirmDeleteConversationFromContact,
            preferredStyle: .alert
        )
        let deleteAction = UIAlertAction(title: L10n.Actions.deleteAction,
                                         style: .destructive) { [weak self] (_: UIAlertAction!) in
            self?.viewModel.deleteConversation()
        }
        let cancelAction = UIAlertAction(title: L10n.Global.cancel,
                                         style: .default) { (_: UIAlertAction!) in }
        alert.addAction(deleteAction)
        alert.addAction(cancelAction)
        present(alert, animated: true, completion: nil)
    }

    private func showBlockContactConfirmation() {
        let alert = UIAlertController(
            title: L10n.Global.blockContact,
            message: L10n.Alerts.confirmBlockContact,
            preferredStyle: .alert
        )
        let blockAction = UIAlertAction(title: L10n.Global.block,
                                        style: .destructive) { [weak self] (_: UIAlertAction!) in
            self?.viewModel.blockContact()
            _ = self?.navigationController?.popToRootViewController(animated: false)
        }
        let cancelAction = UIAlertAction(title: L10n.Global.cancel,
                                         style: .default) { (_: UIAlertAction!) in }
        alert.addAction(blockAction)
        alert.addAction(cancelAction)
        present(alert, animated: true, completion: nil)
    }
}

extension ContactViewController: UITableViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let navigationHeight = navigationController?.navigationBar.bounds.height
        var size = view.bounds.size
        var titlViewThreshold: CGFloat = 0
        let screenSize = UIScreen.main.bounds.size
        if let height = navigationHeight {
            // height for iphoneX
            if UIDevice.current.userInterfaceIdiom == UIUserInterfaceIdiom.phone,
               screenSize.height == 812.0 {
                size.height -= (height - 10)
            }
            titlViewThreshold = height
        }
        if scrollView.contentSize.height < size.height {
            scrollView.contentSize = size
        }
        guard let titleView = navigationItem.titleView as? TitleView else { return }
        titleView.scrollViewDidScroll(scrollView, threshold: titlViewThreshold)
    }

    func scrollViewDidEndDecelerating(_: UIScrollView) {
        scrollViewDidStopScrolling()
    }

    func scrollViewDidEndDragging(_: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            scrollViewDidStopScrolling()
        }
    }

    func scrollViewDidStopScrolling() {
        var contentOffset = tableView.contentOffset
        let middle = (stretchyHeader.maximumContentHeight - stretchyHeader.minimumContentHeight) *
            0.4
        if stretchyHeader.frame.height > middle {
            contentOffset.y = -stretchyHeader.maximumContentHeight
        } else {
            contentOffset.y = -stretchyHeader.minimumContentHeight
        }
        tableView.setContentOffset(contentOffset, animated: true)
    }
}
