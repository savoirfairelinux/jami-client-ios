/*
 *  Copyright (C) 2016 Savoir-faire Linux Inc.
 *
 *  Author: Edric Ladent-Milaret <edric.ladent-milaret@savoirfairelinux.com>
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

class MeViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    // MARK: - Properties
    let accountModel = AccountModel.sharedInstance
    @IBOutlet weak var accountTableView: UITableView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var qrImageView: UIImageView!

    // MARK: - UIViewController
    override func viewDidLoad() {
        super.viewDidLoad()

        if accountModel.accountList.count > 0 {
            let acc = accountModel.accountList[0]
            nameLabel.text = acc.displayName
            if let username = acc.username {
                createQRFromString(username);
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    // MARK: - QRCode
    func createQRFromString(_ str: String) {

        let data = str.data(using: String.Encoding.isoLatin1, allowLossyConversion: false)

        let filter = CIFilter(name: "CIQRCodeGenerator")
        filter!.setValue(data, forKey: "inputMessage")

        let qrImage: CIImage = filter!.outputImage!

        let scaleX = qrImageView.frame.size.width / qrImage.extent.size.width
        let scaleY = qrImageView.frame.size.height / qrImage.extent.size.height

        let resultQrImage = qrImage.applying(CGAffineTransform(scaleX: scaleX, y: scaleY))
        qrImageView.image = UIImage(ciImage: resultQrImage)
    }

    // MARK: - TableView
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1;
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return accountModel.accountList.count + 1
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        if indexPath.row < accountModel.accountList.count {
            let cell = tableView.dequeueReusableCell(withIdentifier: "accountTableCell", for: indexPath) as! AccountTableViewCell
            let account = accountModel.accountList[indexPath.row]

            cell.account = account
            cell.accountNameLabel.text = account.alias
            cell.activeSwitch.setOn(account.isEnabled, animated: false)
            cell.accountTypeLabel.text = account.accountType.rawValue

            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "addAccountTableCell", for: indexPath)
            return cell
        }

    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.row == accountModel.accountList.count {
            accountModel.addAccount()
            accountTableView.reloadData()
        }
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        if indexPath.row == accountModel.accountList.count {
            return false
        }
        return true
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if (editingStyle == UITableViewCellEditingStyle.delete) {
            accountModel.removeAccount(indexPath.row)
            accountTableView.reloadData()
        }
    }

    // MARK: - Actions
    @IBAction func addAccountClicked(_ sender: AnyObject) {
        let index = IndexPath(row: accountModel.accountList.count, section: 0)
        accountTableView.selectRow(at: index, animated: false, scrollPosition: UITableViewScrollPosition.none)
        tableView(accountTableView, didSelectRowAt: index)
    }

    // MARK: - Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "accountDetails" {
            let cell = sender as! AccountTableViewCell
            let vc = segue.destination as! AccountDetailsViewController
            vc.account = cell.account
        }
    }

}
