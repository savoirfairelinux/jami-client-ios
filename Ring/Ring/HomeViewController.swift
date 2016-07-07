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
import CoreData

class HomeViewController: UIViewController, NSFetchedResultsControllerDelegate, UITableViewDataSource {

    // MARK: - Properties
    var fetchedResultsController: NSFetchedResultsController<NSFetchRequestResult>!
    @IBOutlet weak var tableView: UITableView!

    // MARK: - UIViewController
    override func viewDidLoad() {
        super.viewDidLoad()

        let sortDescriptor = NSSortDescriptor(key: "lastUsed", ascending: false)

        fetchedResultsController = Table<Contact>.fetchedResultsController([sortDescriptor])
        fetchedResultsController.delegate = self

        do {
            try fetchedResultsController.performFetch()
        } catch {
            fatalError("Failed to initialize FetchedResultsController: \(error)")
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    // MARK: - UITableViewDataSource
    func tableView(_ tableView: UITableView,
        numberOfRowsInSection section: Int) -> Int {
            guard let sections = fetchedResultsController.sections else {
                fatalError("No sections in fetchedResultsController")
            }
            let sectionInfo = sections[section]
            return sectionInfo.numberOfObjects
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return fetchedResultsController.sections!.count
    }

    func configureCell(_ cell: UITableViewCell, indexPath: IndexPath) {
        guard let selectedObject = fetchedResultsController.object(at: indexPath) as? Contact
        else {
            fatalError("Error fetching contacts")
        }
        cell.textLabel!.text = selectedObject.displayName != nil ? selectedObject.displayName : selectedObject.uri
    }

    func tableView(_ tableView: UITableView,
        cellForRowAt indexPath: IndexPath) -> UITableViewCell {

            let cell = tableView.dequeueReusableCell(withIdentifier: "contactCell", for: indexPath)
            configureCell(cell, indexPath: indexPath)
            return cell
    }

    // MARK: - NSFetchedResultsControllerDelegate
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.beginUpdates()
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        switch type {
        case .insert:
            tableView.insertSections(IndexSet(integer: sectionIndex), with: .fade)
        case .delete:
            tableView.deleteSections(IndexSet(integer: sectionIndex), with: .fade)
        case .move:
            break
        case .update:
            break
        }
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch type {
        case .insert:
            tableView.insertRows(at: [newIndexPath!], with: .fade)
        case .delete:
            tableView.deleteRows(at: [indexPath!], with: .fade)
        case .update:
            configureCell(tableView.cellForRow(at: indexPath!)!, indexPath: indexPath!)
        case .move:
            tableView.moveRow(at: indexPath!, to: newIndexPath!)
        }
    }

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.endUpdates()
    }
}
