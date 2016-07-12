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

import Foundation
import CoreData

class Table<T: ManagedObject> {

    // MARK: Create functions
    static func create(setup: T -> Void) {

        let moc = CDManager.sharedInstance.managedObjectContext
        do {
            let entityDescription = NSEntityDescription.entityForName(T.entityName, inManagedObjectContext: moc)
            let newElem = T(entity: entityDescription!, insertIntoManagedObjectContext: moc)
            setup(newElem)
            try moc.save()
        } catch {
            print("Error creating \(T.entityName)")
        }
    }

    static func createIfNotExist(predicate: NSPredicate, setup: T -> Void) -> Bool {

        let managedObjectContext = CDManager.sharedInstance.managedObjectContext
        let fetchRequest = NSFetchRequest(entityName: T.entityName)
        fetchRequest.predicate = predicate
        do {
            let fetchedContact = try managedObjectContext.executeFetchRequest(fetchRequest)
            if fetchedContact.count == 0 {
                self.create(setup)
                return true
            }
        } catch {
            print("Create if not exist for \(T.entityName) failed")
        }
        return false
    }

    // MARK: - Read functions
    static func fetchedResultsController(sortDescriptors: [NSSortDescriptor] = [], predicate: NSPredicate? = nil) -> NSFetchedResultsController {

        let moc = CDManager.sharedInstance.managedObjectContext
        let request = NSFetchRequest(entityName: T.entityName)
        request.sortDescriptors = sortDescriptors
        request.predicate = predicate
        return NSFetchedResultsController(fetchRequest: request,
            managedObjectContext: moc,
            sectionNameKeyPath: nil,
            cacheName: nil)
    }

    static func find(predicate: NSPredicate) -> [T] {
        let moc = CDManager.sharedInstance.managedObjectContext
        let request = NSFetchRequest(entityName: T.entityName)
        request.predicate = predicate
        do {
            let res = try moc.executeFetchRequest(request) as! [T]
            return res
        } catch {
            print("Find for \(T.entityName) failed")
        }
        return []
    }

    // MARK: - Delete functions
    static func delete(toDelete obj: ManagedObject) -> Bool {

        let moc = CDManager.sharedInstance.managedObjectContext
        moc.deleteObject(obj)
        do {
            try moc.save()
        } catch {
            print ("Delete failed for \(T.entityName)")
            return false
        }
        return true
    }
}
