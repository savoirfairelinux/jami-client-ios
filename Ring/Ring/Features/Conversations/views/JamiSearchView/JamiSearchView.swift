/*
*  Copyright (C) 2020 Savoir-faire Linux Inc.
*
*  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
*  Author: Raphaël Brulé <raphael.brule@savoirfairelinux.com>
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
import RxDataSources
import RxCocoa
import Reusable

class JamiSearchView: NSObject {

    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var searchingLabel: UILabel!
    @IBOutlet weak var searchResultsTableView: UITableView!

    private var viewModel: JamiSearchViewModel!
    private let disposeBag = DisposeBag()
    var editSearch = PublishSubject<Bool>()
    var isIncognito = false

    let incognitoCellHeight: CGFloat = 150
    let incognitoHeaderHeight: CGFloat = 0

    func configure(with injectionBag: InjectionBag, source: FilterConversationDataSource, isIncognito: Bool) {
        self.viewModel = JamiSearchViewModel(with: injectionBag, source: source)
        self.isIncognito = isIncognito
        self.setUpView()
    }

    private func setUpView() {
        configureSearchResult()
        configureSearchBar()
    }
    private func cancelSearch() {
        self.searchBar.text = ""
        self.searchBar.resignFirstResponder()
        self.searchResultsTableView.isHidden = true
    }

    private func configureSearchResult() {
        if self.isIncognito {
            self.searchResultsTableView.register(cellType: IncognitoSmartListCell.self)
            self.searchResultsTableView.rowHeight = self.incognitoCellHeight

        } else {
            self.searchResultsTableView.register(cellType: SmartListCell.self)
            self.searchResultsTableView.rowHeight = SmartlistConstants.smartlistRowHeight
            self.searchResultsTableView.tableFooterView = UIView()
        }
        self.searchResultsTableView.backgroundColor = UIColor.jamiBackgroundColor

        self.searchResultsTableView.rx.setDelegate(self).disposed(by: disposeBag)

        let configureCell: (TableViewSectionedDataSource, UITableView, IndexPath, ConversationSection.Item) -> UITableViewCell = {
            (dataSource: TableViewSectionedDataSource<ConversationSection>,
            tableView: UITableView,
            indexPath: IndexPath,
            conversationItem: ConversationSection.Item) in

            let cellType = self.isIncognito ? IncognitoSmartListCell.self : SmartListCell.self
            let cell = tableView.dequeueReusableCell(for: indexPath, cellType: cellType)
            cell.configureFromItem(conversationItem)
            return cell
        }
        let searchResultsDatasource = RxTableViewSectionedReloadDataSource<ConversationSection>(configureCell: configureCell)

        self.viewModel
            .searchResults
            .map({ (conversations) -> Bool in return conversations.isEmpty })
            .subscribe(onNext: { [weak self] (hideFooterView) in
                self?.searchResultsTableView.tableFooterView?.isHidden = hideFooterView })
            .disposed(by: disposeBag)

        self.viewModel
            .searchResults
            .bind(to: self.searchResultsTableView.rx.items(dataSource: searchResultsDatasource))
            .disposed(by: disposeBag)

        self.searchResultsTableView.rx.itemSelected
            .subscribe(onNext: { [weak self] indexPath in
                self?.searchResultsTableView.deselectRow(at: indexPath, animated: true) })
            .disposed(by: disposeBag)

        searchResultsDatasource.titleForHeaderInSection = { dataSource, index in
            return dataSource.sectionModels[index].header
        }
        //search status label
        self.viewModel.searchStatus
            .observeOn(MainScheduler.instance)
            .bind(to: self.searchingLabel.rx.text)
            .disposed(by: disposeBag)
        searchingLabel.textColor = UIColor.jamiLabelColor

        self.viewModel.isSearching
            .subscribe(onNext: { [weak self] (isSearching) in
                self?.searchResultsTableView.isHidden = !isSearching
                self?.searchingLabel.isHidden = !isSearching
            })
            .disposed(by: disposeBag)

        self.viewModel.searchStatus
            .subscribe(onNext: { [weak self] (searchText) in
                self?.searchResultsTableView.contentInset.top = searchText.isEmpty ? 0 : 24
            })
            .disposed(by: disposeBag)
    }

    private func configureSearchBar() {
        self.searchBar.rx.text.orEmpty
            .debounce(Durations.textFieldThrottlingDuration.toTimeInterval(), scheduler: MainScheduler.instance)
            .bind(to: self.viewModel.searchBarText)
            .disposed(by: disposeBag)

        //Show Cancel button
        self.searchBar.rx.textDidBeginEditing
            .subscribe(onNext: { [weak self] in
                self?.editSearch.onNext(true)
                self?.searchBar.setShowsCancelButton(true, animated: false)
            })
            .disposed(by: disposeBag)

        //Hide Cancel button
        self.searchBar.rx.textDidEndEditing
            .subscribe(onNext: { [weak self] in
                guard let self = self else { return }
                self.searchBar.setShowsCancelButton(false, animated: false)
                if self.isIncognito && !(self.searchBar.text?.isEmpty ?? true) {
                    return
                }
                self.editSearch.onNext(false)
            })
            .disposed(by: disposeBag)

        //Cancel button event
        self.searchBar.rx.cancelButtonClicked
            .subscribe(onNext: { [weak self] in
                self?.cancelSearch()
            })
            .disposed(by: disposeBag)

        //Search button event
        self.searchBar.rx.searchButtonClicked
            .subscribe(onNext: { [weak self] in
                self?.searchBar.resignFirstResponder()
            })
            .disposed(by: disposeBag)

        searchBar.returnKeyType = .done
        searchBar.autocapitalizationType = .none
        searchBar.tintColor = UIColor.jamiMain
        searchBar.placeholder = L10n.Smartlist.searchBarPlaceholder
        searchBar.searchBarStyle = .minimal
        searchBar.backgroundImage = UIImage()
        searchBar.backgroundColor = UIColor.clear
    }
}

// MARK: UITableViewDelegate
extension JamiSearchView: UITableViewDelegate {

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard let headerView = view as? UITableViewHeaderFooterView else { return }
        headerView.tintColor = .clear
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return isIncognito ? incognitoHeaderHeight : SmartlistConstants.tableHeaderViewHeight
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let convToShow: ConversationViewModel = try? tableView.rx.model(at: indexPath) {
            self.viewModel.showConversation(conversation: convToShow)
        }
    }
}
