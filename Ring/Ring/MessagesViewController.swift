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

        self.tableView.estimatedRowHeight = 30
        self.tableView.rowHeight = UITableViewAutomaticDimension
        self.tableView.separatorStyle = .none

        self.tableView.register(UINib.init(nibName: "MessageCell", bundle: nil),
                                forCellReuseIdentifier: "MessageCellId")

        //Bind the TableView to the ViewModel
        self.viewModel?.messages.asObservable()
            .bindTo(tableView.rx.items(cellIdentifier: "MessageCellId", cellType: MessageCell.self))
            { index, viewModel, cell in
            cell.messageLabel.text = viewModel.content
        }.addDisposableTo(disposeBag)
    }
    
}
