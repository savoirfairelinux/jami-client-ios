/*
 * Copyright (C) 2017-2026 Savoir-faire Linux Inc.
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

/// Typed audio-device commands toward libjami.
protocol LibJamiAudioAPI: AnyObject {
    func setAudioOutputDevice(_ index: Int)
    func setAudioInputDevice(_ index: Int)
}

/// Production implementation over the kept ObjC++ `AudioAdapter`.
final class LibJamiAudioClient: LibJamiAudioAPI {

    private let adapter: AudioAdapter

    init(adapter: AudioAdapter) {
        self.adapter = adapter
    }

    func setAudioOutputDevice(_ index: Int) {
        adapter.setAudioOutputDevice(index)
    }

    func setAudioInputDevice(_ index: Int) {
        adapter.setAudioInputDevice(index)
    }
}
