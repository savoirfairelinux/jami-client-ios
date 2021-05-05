//
//  CustomSearchController.swift
//  Ring
//
//  Created by kateryna on 2021-04-30.
//  Copyright © 2021 Savoir-faire Linux. All rights reserved.
//

import UIKit

class CustomSearchController: UISearchController {
    private var customSearchBar = CustomSearchBar()
        override public var searchBar: UISearchBar {
            get {
                return customSearchBar
            }
        }
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override init(searchResultsController: UIViewController?) {
        super.init(searchResultsController: searchResultsController)
//        self.view.backgroundColor = UIColor.red
//        let image = UIImage(asset: Asset.qrCode)
//        scanButton = UIButton(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
//        scanButton.setImage(image, for: .normal)
//        scanButton.tintColor = UIColor.jamiMain
//        self.view.addSubview(scanButton)
    }

    required init?(coder: NSCoder) {
        super .init(coder: coder)
    }

    func setup() {
        customSearchBar.setUp()
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
