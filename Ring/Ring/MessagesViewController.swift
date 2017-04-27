//
//  MessagesViewController.swift
//  Ring
//
//  Created by Silbino Goncalves Matado on 17-04-27.
//  Copyright © 2017 Savoir-faire Linux. All rights reserved.
//

import UIKit
import RxSwift

class MessagesViewController: UITableViewController {

    let disposeBag = DisposeBag()

    var viewModel: ConversationViewModel?

    override func viewDidLoad() {
        super.viewDidLoad()

        //Bind the TableView to the ViewModel
        self.viewModel?.messages.asObservable().bindTo(tableView.rx.items(cellIdentifier: "MessageCellId") ) { index, viewModel, cell in
            cell.textLabel?.text = viewModel.content
        }.addDisposableTo(disposeBag)
    }
    
}
