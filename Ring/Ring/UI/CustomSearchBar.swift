//
//  CustomSearchBar.swift
//  Ring
//
//  Created by kateryna on 2021-04-30.
//  Copyright © 2021 Savoir-faire Linux. All rights reserved.
//

import UIKit

class CustomSearchBar: UISearchBar {
    var scanButton = UIButton()
    /*
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        // Drawing code
    }
    */

    public required init?(coder aDecoder: NSCoder) {
            super.init(coder: aDecoder)
        }
    init() {
            super.init(frame: CGRect.zero)
        }

    func setUp() {
        let image = UIImage(asset: Asset.qrCode)
        let width = self.frame.size.width - 80
        scanButton = UIButton(frame: CGRect(x: self.frame.size.width - 50, y: 8, width: 40, height: 40))
        scanButton.setImage(image, for: .normal)
        scanButton.tintColor = UIColor.jamiMain
        self.addSubview(scanButton)
        scanButton.translatesAutoresizingMaskIntoConstraints = true
        if #available(iOS 13.0, *) {
            self.searchTextField.translatesAutoresizingMaskIntoConstraints = false
           // self.searchTextField.backgroundColor = UIColor.red
            self.searchTextField.trailingAnchor.constraint(equalTo: scanButton.trailingAnchor, constant: -50).isActive = true
            self.searchTextField.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 20).isActive = true
            self.searchTextField.topAnchor.constraint(equalTo: self.topAnchor, constant: 10).isActive = true
            //self.searchTextField.topAnc
            //self.searchTextField.widthAncho.constraint(equalTo: self.leadingAnchor, constant: 20).isActive = true
            //self.searchTextField.topAncr.constraint(equalToConstant: width).isActive = true
        }
        //self.backgroundColor = UIColor.red
//        if let background = self.subviews.compactMap({ $0 as? _UISearchBarSearchFieldBackgroundView }).first {
//
//        }
        //_UISearchBarSearchFieldBackgroundView
//        let widthField = 0
//        for view in subviews {
//                    if let searchField = view as? UITextField {
//                        scanButton = UIButton(frame: CGRect(x: searchField.frame.width + 20, y: 0, width: 40, height: 40))
//                        scanButton.setImage(image, for: .normal)
//                        scanButton.tintColor = UIColor.jamiMain
//                        self.addSubview(scanButton)
//                        var textFrame = searchField.frame
//                        textFrame.size.width -= 80
//                        searchField.frame = textFrame
//                        return
//                    } else {
//                        for sView in view.subviews {
//                            if let searchField = sView as? UITextField {
//                                scanButton = UIButton(frame: CGRect(x: searchField.frame.width + 20, y: 0, width: 40, height: 40))
//                                scanButton.setImage(image, for: .normal)
//                                scanButton.tintColor = UIColor.jamiMain
//                                self.addSubview(scanButton)
//                                var textFrame = searchField.frame
//                                textFrame.size.width -= 80
//                                searchField.frame = textFrame
//                                return
//                            }
//                        }
//                    }
//                }
//        if #available(iOS 13.0, *) {
//            scanButton = UIButton(frame: CGRect(x: self.searchTextField.frame.width + 20, y: 0, width: 40, height: 40))
//            scanButton.setImage(image, for: .normal)
//            scanButton.tintColor = UIColor.jamiMain
//            self.addSubview(scanButton)
//        } else {
//            // Fallback on earlier versions
//        }
////                scanButton.setImage(image, for: .normal)
////                scanButton.tintColor = UIColor.jamiMain
////                self.addSubview(scanButton)
//        if #available(iOS 13.0, *) {
//            var textFrame = self.searchTextField.frame
//            textFrame.size.width -= 80
//            self.searchTextField.frame = textFrame
//        } else {
//            // Fallback on earlier versions
//        }
    }

}
