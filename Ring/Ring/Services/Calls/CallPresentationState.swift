/*
 * Copyright (C) 2026 Savoir-faire Linux Inc.
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
import RxRelay

/// Durable single-call presentation state. Unlike a `PublishSubject`, the
/// relay replays the current call to a presenter created after CallKit answers.
final class CallPresentationState {
    let call = BehaviorRelay<CallState?>(value: nil)

    func present(_ call: CallState) {
        set(call)
    }

    func replace(_ replaced: CallId, with call: CallState) {
        guard self.call.value?.id == replaced else { return }
        set(call)
    }

    func clear(_ callId: CallId) {
        guard call.value?.id == callId else { return }
        set(nil)
    }

    /// CallKit answers and libjami events both reach the relay on the main
    /// queue; the presenter's replay depends on that single writer.
    private func set(_ call: CallState?) {
#if DEBUG
        dispatchPrecondition(condition: .onQueue(.main))
#endif
        self.call.accept(call)
    }
}
