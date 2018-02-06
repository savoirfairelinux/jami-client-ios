//
//  ProxyCell.swift
//  Ring
//
//  Created by Kateryna Kostiuk on 2018-02-06.
//  Copyright © 2018 Savoir-faire Linux. All rights reserved.
//

import UIKit
import Reusable
import RxSwift

class ProxyCell: UITableViewCell, NibReusable {

    @IBOutlet weak var enableProxyLabel: UILabel!
    @IBOutlet weak var switchProxy: UISwitch!

    var disposeBag = DisposeBag()

    override func prepareForReuse() {
        self.disposeBag = DisposeBag()
    }
}
