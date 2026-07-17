/*
 * Copyright (C) 2026-2026 Savoir-faire Linux Inc.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA.
 */

import Foundation

// Single source of truth for whether the account(s) should be DHT-active — only
// one process may hold the account active at a time. Applies
// `isForeground || callActive` on one serial queue, on genuine change only.
final class AccountActivationManager {

    private let queue = DispatchQueue(label: "cx.ring.accountActive")
    private var isForeground: Bool
    private var callActive: Bool
    private let apply: (Bool) -> Void
    private var lastApplied: Bool?

    init(isForeground: Bool,
         callActive: Bool = false,
         apply: @escaping (Bool) -> Void) {
        self.isForeground = isForeground
        self.callActive = callActive
        self.apply = apply
        queue.async { [weak self] in
            self?.updateActiveState()
        }
    }

    func setForeground(_ foreground: Bool) {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.isForeground = foreground
            self.updateActiveState()
        }
    }

    func setCallActive(_ active: Bool) {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.callActive = active
            self.updateActiveState()
        }
    }

    private func updateActiveState() {
        let desired = isForeground || callActive
        guard desired != lastApplied else { return }
        lastApplied = desired
        apply(desired)
    }
}

#if DEBUG
extension AccountActivationManager {
    func waitForPendingWork() {
        queue.sync {}
    }
}
#endif
