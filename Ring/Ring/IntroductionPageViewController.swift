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

        let welcomePage: UIViewController! = storyboard?.instantiateViewController(withIdentifier: "WelcomePage")
        let accountPage: UIViewController! = storyboard?.instantiateViewController(withIdentifier: "AccountPage")
        let permissionsPage: UIViewController! = storyboard?.instantiateViewController(withIdentifier: "PermissionsPage")

        pages.append(welcomePage)
        pages.append(accountPage)
        pages.append(permissionsPage)

        self.view.backgroundColor = welcomePage.view.backgroundColor

        setViewControllers([welcomePage],
            direction: UIPageViewControllerNavigationDirection.forward,
            animated: false,
            completion: nil)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    // MARK: - UIPageViewControllerDataSource

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        let currentIndex = pages.index(of: viewController)!

        if currentIndex == 0 {
            return nil
        } else {
            let previousPage = pages[currentIndex - 1]
            self.view.backgroundColor = previousPage.view.backgroundColor
            return previousPage
        }
    }

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        let currentIndex = pages.index(of: viewController)!

        if currentIndex + 1 == pages.count {
            return nil
        } else {
            let nextPage = pages[currentIndex + 1]
            self.view.backgroundColor = nextPage.view.backgroundColor
            return nextPage
        }
    }

    func presentationCount(for pageViewController: UIPageViewController) -> Int {
        return pages.count
    }

    func presentationIndex(for pageViewController: UIPageViewController) -> Int {
        return pages.index(of: pageViewController.viewControllers![0])!
    }

    // MARK: - Utils Function

    func nextPage() {
        let currentIndex = pages.index(of: self.viewControllers![0])!
        if currentIndex + 1 == pages.count {
            return
        } else {
            let nextPage = pages[currentIndex + 1]
            setViewControllers([nextPage],
                direction: UIPageViewControllerNavigationDirection.forward,
                animated: true,
                completion: nil)
        }
    }

}
