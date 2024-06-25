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

import Reusable
import RxCocoa
import RxDataSources
import RxSwift
import UIKit

class JamiSearchView: NSObject {
    @IBOutlet var searchBar: UISearchBar!
    @IBOutlet var searchingLabel: UILabel!
    @IBOutlet var searchResultsTableView: UITableView!

    private var viewModel: JamiSearchViewModel!
    private let disposeBag = DisposeBag()
    var editSearch = PublishSubject<Bool>()
    var isIncognito = false

    let incognitoCellHeight: CGFloat = 150
    let incognitoHeaderHeight: CGFloat = 0
    var showSearchResult: Bool = true

    func configure(
        with injectionBag: InjectionBag,
        source: FilterConversationDataSource,
        isIncognito: Bool,
        delegate: FilterConversationDelegate?
    ) {
        viewModel = JamiSearchViewModel(
            with: injectionBag,
            source: source,
            searchOnlyExistingConversations: true
        )
        viewModel.setDelegate(delegate: delegate)
        self.isIncognito = isIncognito
        setUpView()
    }

    private func setUpView() {
        configureSearchResult()
        configureSearchBar()
    }

    private func cancelSearch() {
        searchBar.text = ""
        searchBar.resignFirstResponder()
        searchResultsTableView.isHidden = true
    }

    private func configureSearchResult() {
        if isIncognito {
            searchResultsTableView.register(cellType: IncognitoSmartListCell.self)
            searchResultsTableView.rowHeight = incognitoCellHeight

        } else {
            searchResultsTableView.register(cellType: SmartListCell.self)
            searchResultsTableView.rowHeight = SmartlistConstants.smartlistRowHeight
        }
        searchResultsTableView.backgroundColor = UIColor.jamiBackgroundColor

        searchResultsTableView.rx.setDelegate(self).disposed(by: disposeBag)

        let configureCell: (
            TableViewSectionedDataSource,
            UITableView,
            IndexPath,
            ConversationSection.Item
        ) -> UITableViewCell = {
            (_: TableViewSectionedDataSource<ConversationSection>,
             tableView: UITableView,
             indexPath: IndexPath,
             conversationItem: ConversationSection.Item) in

            let cellType = self.isIncognito ? IncognitoSmartListCell.self : SmartListCell.self
            let cell = tableView.dequeueReusableCell(for: indexPath, cellType: cellType)
            cell.configureFromItem(conversationItem)
            return cell
        }
        let searchResultsDatasource =
            RxTableViewSectionedReloadDataSource<ConversationSection>(configureCell: configureCell)

        viewModel
            .searchResults
            .bind(to: searchResultsTableView.rx.items(dataSource: searchResultsDatasource))
            .disposed(by: disposeBag)
        viewModel
            .searchResults
            .map { conversations -> Bool in conversations.isEmpty }
            .subscribe(onNext: { [weak self] hideFooterView in
                self?.searchResultsTableView.tableFooterView?.isHidden = hideFooterView
            })
            .disposed(by: disposeBag)

        searchResultsTableView.rx.itemSelected
            .subscribe(onNext: { [weak self] indexPath in
                self?.searchResultsTableView.deselectRow(at: indexPath, animated: true)
            })
            .disposed(by: disposeBag)

        searchResultsDatasource.titleForHeaderInSection = { dataSource, index in
            dataSource.sectionModels[index].header
        }
        // search status label
        viewModel.searchStatus
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] status in
                guard let self = self else { return }
                self.searchingLabel.text = status.toString()
                self.searchingLabel.isHidden = status.toString().isEmpty
            })
            .disposed(by: disposeBag)
        searchingLabel.textColor = UIColor.jamiLabelColor

        viewModel.isSearching
            .subscribe(onNext: { [weak self] isSearching in
                guard let self = self else { return }
                self.searchResultsTableView.isHidden = !isSearching
                let resultvisible = isSearching && self.showSearchResult
                self.searchingLabel.isHidden = !resultvisible
            })
            .disposed(by: disposeBag)
    }

    private func configureSearchBar() {
        searchBar.rx.text.orEmpty
            .debounce(
                Durations.textFieldThrottlingDuration.toTimeInterval(),
                scheduler: MainScheduler.instance
            )
            .bind(to: viewModel.searchBarText)
            .disposed(by: disposeBag)
        searchBar.placeholder = L10n.Smartlist.searchBar
    }
}

// MARK: UITableViewDelegate

extension JamiSearchView: UITableViewDelegate {
    func tableView(_: UITableView, heightForHeaderInSection _: Int) -> CGFloat {
        return isIncognito ? incognitoHeaderHeight : SmartlistConstants.tableHeaderViewHeight
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let convToShow: ConversationViewModel = try? tableView.rx.model(at: indexPath) {
            viewModel.showConversation(conversation: convToShow)
        }
    }
}
