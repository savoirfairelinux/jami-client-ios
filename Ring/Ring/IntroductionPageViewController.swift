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

class IntroductionPageViewController: UIPageViewController, UIPageViewControllerDataSource, UIPageViewControllerDelegate {

    // MARK: Properties
    var pages = [UIViewController]()

    // MARK: - UIViewController
    override func viewDidLoad() {
        super.viewDidLoad()

        self.delegate = self
        self.dataSource = self

        let welcomePage: UIViewController! = storyboard?.instantiateViewControllerWithIdentifier("WelcomePage")
        let accountPage: UIViewController! = storyboard?.instantiateViewControllerWithIdentifier("AccountPage")
        let permissionsPage: UIViewController! = storyboard?.instantiateViewControllerWithIdentifier("PermissionsPage")

        pages.append(welcomePage)
        pages.append(accountPage)
        pages.append(permissionsPage)

        self.view.backgroundColor = welcomePage.view.backgroundColor

        setViewControllers([welcomePage],
            direction: UIPageViewControllerNavigationDirection.Forward,
            animated: false,
            completion: nil)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    // MARK: - UIPageViewControllerDataSource

    func pageViewController(pageViewController: UIPageViewController, viewControllerBeforeViewController viewController: UIViewController) -> UIViewController? {
        let currentIndex = pages.indexOf(viewController)!

        if currentIndex == 0 {
            return nil
        } else {
            let previousPage = pages[currentIndex - 1]
            self.view.backgroundColor = previousPage.view.backgroundColor
            return previousPage
        }
    }

    func pageViewController(pageViewController: UIPageViewController, viewControllerAfterViewController viewController: UIViewController) -> UIViewController? {
        let currentIndex = pages.indexOf(viewController)!

        if currentIndex + 1 == pages.count {
            return nil
        } else {
            let nextPage = pages[currentIndex + 1]
            self.view.backgroundColor = nextPage.view.backgroundColor
            return nextPage
        }
    }

    func presentationCountForPageViewController(pageViewController: UIPageViewController) -> Int {
        return pages.count
    }

    func presentationIndexForPageViewController(pageViewController: UIPageViewController) -> Int {
        return pages.indexOf(pageViewController.viewControllers![0])!
    }

    // MARK: - Utils Function

    func nextPage() {
        let currentIndex = pages.indexOf(self.viewControllers![0])!
        if currentIndex + 1 == pages.count {
            return
        } else {
            let nextPage = pages[currentIndex + 1]
            setViewControllers([nextPage],
                direction: UIPageViewControllerNavigationDirection.Forward,
                animated: true,
                completion: nil)
        }
    }

}
