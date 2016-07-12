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

import CoreData
import UIKit

class ConversationsViewController: UIViewController, NSFetchedResultsControllerDelegate, UITableViewDataSource {

    // MARK: - Properties
    @IBOutlet weak var textField: UITextField!
    var contact: Contact!
    var fetchedResultsController: NSFetchedResultsController!
    @IBOutlet weak var tableView: UITableView!

    override func viewDidLoad() {
        super.viewDidLoad()

        let predicate = NSPredicate(format: "contact.uri == %@", contact.uri!)
        let sortDescriptor = NSSortDescriptor(key: "received", ascending: true)

        fetchedResultsController = Table<Messages>.fetchedResultsController([sortDescriptor], predicate: predicate)
        fetchedResultsController.delegate = self

        do {
            try fetchedResultsController.performFetch()
        } catch {
            fatalError("Failed to initialize FetchedResultsController: \(error)")
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - UITableViewDataSource
    func tableView(tableView: UITableView,
        numberOfRowsInSection section: Int) -> Int {
            guard let sections = fetchedResultsController.sections else {
                fatalError("No sections in fetchedResultsController")
            }
            let sectionInfo = sections[section]
            return sectionInfo.numberOfObjects
    }

    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return fetchedResultsController.sections!.count
    }

    func configureCell(cell: UITableViewCell, indexPath: NSIndexPath) {
        guard let selectedObject = fetchedResultsController.objectAtIndexPath(indexPath) as? Messages
        else {
            fatalError("Error fetching contacts")
        }
        cell.textLabel!.text = selectedObject.payload
    }

    func tableView(tableView: UITableView,
        cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {

            let cell = tableView.dequeueReusableCellWithIdentifier("messageCell", forIndexPath: indexPath)
            configureCell(cell, indexPath: indexPath)
            return cell
    }

    // MARK: - NSFetchedResultsControllerDelegate
    func controllerWillChangeContent(controller: NSFetchedResultsController) {
        tableView.beginUpdates()
    }

    func controller(controller: NSFetchedResultsController, didChangeSection sectionInfo: NSFetchedResultsSectionInfo, atIndex sectionIndex: Int, forChangeType type: NSFetchedResultsChangeType) {
        switch type {
        case .Insert:
            tableView.insertSections(NSIndexSet(index: sectionIndex), withRowAnimation: .Fade)
        case .Delete:
            tableView.deleteSections(NSIndexSet(index: sectionIndex), withRowAnimation: .Fade)
        case .Move:
            break
        case .Update:
            break
        }
    }

    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        switch type {
        case .Insert:
            tableView.insertRowsAtIndexPaths([newIndexPath!], withRowAnimation: .Fade)
        case .Delete:
            tableView.deleteRowsAtIndexPaths([indexPath!], withRowAnimation: .Fade)
        case .Update:
            configureCell(tableView.cellForRowAtIndexPath(indexPath!)!, indexPath: indexPath!)
        case .Move:
            tableView.moveRowAtIndexPath(indexPath!, toIndexPath: newIndexPath!)
        }
    }

    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        tableView.endUpdates()
    }

    // MARK: - Actions
    @IBAction func onSendPressed(sender: AnyObject) {
        if let text = textField.text {
            let manager = ConfigurationManagerAdaptator.sharedManager()
            let payloads = ["text/plain": text]
            let accID = AccountModel.sharedInstance.accountList[0].id
            manager.sendAccountTextMessage(accID, to: contact.uri, payloads: payloads)
            Table<Messages>.create() {
                $0.contact = self.contact
                $0.payload = text
                $0.sentOut = true
                $0.received = NSDate().timeIntervalSince1970
            }
            textField.text = nil
        }
    }

}
