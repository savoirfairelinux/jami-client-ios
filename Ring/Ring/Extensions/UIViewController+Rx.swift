/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
 *
 *  Author: Thibault Wittemberg <thibault.wittemberg@savoirfairelinux.com>
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
import UIKit
import RxSwift
import RxCocoa

extension Reactive where Base: UIViewController {
    public var viewDidLoad: ControlEvent<Void> {
        let source = self.sentMessage(#selector(Base.viewDidLoad)).map { _ in }
        return ControlEvent(events: source)
    }

    public var viewWillAppear: ControlEvent<Bool> {
        let source = self.sentMessage(#selector(Base.viewWillAppear)).map { $0.first as? Bool ?? false }
        return ControlEvent(events: source)
    }

    public var viewDidAppear: ControlEvent<Bool> {
        let source = self.sentMessage(#selector(Base.viewDidAppear)).map { $0.first as? Bool ?? false }
        return ControlEvent(events: source)
    }

    public var viewWillDisappear: ControlEvent<Bool> {
        let source = self.sentMessage(#selector(Base.viewWillDisappear)).map { $0.first as? Bool ?? false }
        return ControlEvent(events: source)
    }

    public var viewDidDisappear: ControlEvent<Bool> {
        let source = self.sentMessage(#selector(Base.viewDidDisappear)).map { $0.first as? Bool ?? false }
        return ControlEvent(events: source)
    }

    public var viewWillLayoutSubviews: ControlEvent<Void> {
        let source = self.sentMessage(#selector(Base.viewWillLayoutSubviews)).map { _ in }
        return ControlEvent(events: source)
    }

    public var viewDidLayoutSubviews: ControlEvent<Void> {
        let source = self.sentMessage(#selector(Base.viewDidLayoutSubviews)).map { _ in }
        return ControlEvent(events: source)
    }

    public var willMoveToParentViewController: ControlEvent<UIViewController?> {
        let source = self.sentMessage(#selector(Base.willMove)).map { $0.first as? UIViewController }
        return ControlEvent(events: source)
    }
    public var didMoveToParentViewController: ControlEvent<UIViewController?> {
        let source = self.sentMessage(#selector(Base.didMove)).map { $0.first as? UIViewController }
        return ControlEvent(events: source)
    }

    public var didReceiveMemoryWarning: ControlEvent<Void> {
        let source = self.sentMessage(#selector(Base.didReceiveMemoryWarning)).map { _ in }
        return ControlEvent(events: source)
    }

    public var controllerWasDismissed: ControlEvent<Bool> {

        let source = self.sentMessage(#selector(Base.viewWillDisappear))
            .filter({ _ in
                return self.base.isBeingDismissed
            })
            .map { $0.first as? Bool ?? false }

        return ControlEvent(events: source)
    }
}
