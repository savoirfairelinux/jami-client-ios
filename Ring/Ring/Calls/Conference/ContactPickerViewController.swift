//
//  ContactPickerViewController.swift
//  Ring
//
//  Created by kate on 2019-11-01.
//  Copyright © 2019 Savoir-faire Linux. All rights reserved.
//

import UIKit
import RxSwift
import RxDataSources
import RxCocoa
import Reusable
import SwiftyBeaver

class ContactPickerViewController: UITableViewController, StoryboardBased, ViewModelBased {
    
    private let log = SwiftyBeaver.self
    @IBOutlet weak var searchBar: UISearchBar!

    var viewModel: ContactPickerViewModel!
    fileprivate let disposeBag = DisposeBag()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupDataSources()
        self.setupTableViews()
        self.setupSearchBar()
        //self.setupUI()
        self.applyL10n()
    }

    func applyL10n() {

    }

    func setupDataSources() {
        let configureCell: (TableViewSectionedDataSource, UITableView, IndexPath, ContactPickerSection.Item)
            -> UITableViewCell = {
                (   dataSource: TableViewSectionedDataSource<ContactPickerSection>,
                tableView: UITableView,
                indexPath: IndexPath,
               contactItem: ContactPickerSection.Item) in

                let cell = tableView.dequeueReusableCell(for: indexPath, cellType: ConversationCell.self)
                cell.nameLabel.text = contactItem.contacts.first?.displayName
                //cell.configureFromItem(conversationItem)
                return cell
        }
        let contactDataSource = RxTableViewSectionedReloadDataSource<ContactPickerSection>(configureCell: configureCell)
        self.viewModel.searchResultItems
            .bind(to: self.tableView.rx.items(dataSource: contactDataSource))
            .disposed(by: disposeBag)
        contactDataSource.titleForHeaderInSection = { dataSource, index in
            return dataSource.sectionModels[index].header
        }
    }

    func setupTableViews() {
        self.tableView.rowHeight = 64.0
        self.tableView.register(cellType: ConversationCell.self)
        self.tableView.rx.itemSelected.subscribe(onNext: { [unowned self] indexPath in
            self.viewModel.addContactToConference()
        }).disposed(by: disposeBag)
    }

    func setupSearchBar() {
        
        self.searchBar.returnKeyType = .done
        self.searchBar.autocapitalizationType = .none
        self.searchBar.tintColor = UIColor.jamiMain
        self.searchBar.barTintColor =  UIColor.jamiNavigationBar
        self.searchBar.rx.text.orEmpty
            .debounce(Durations.textFieldThrottlingDuration.value, scheduler: MainScheduler.instance)
            .bind(to: self.viewModel.search)
            .disposed(by: disposeBag)
    }
}
