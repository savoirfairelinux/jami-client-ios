/*
 *  Copyright (C) 2018 Savoir-faire Linux Inc.
 *
 *  Author: Andreas Traczyk <andreas.traczyk@savoirfairelinux.com>
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

@objc protocol VideoAdapterDelegate {
    func decodingStarted(withRendererId rendererId: String, withWidth width: Int, withHeight height: Int)
    func decodingStopped(withRendererId rendererId: String)
    func startCapture(withDevice device: String)
    func stopCapture()
    func writeFrame(withRendererId rendererId: String, withWidth width: Int, withHeight height: Int, withBuffer data: NSData)
}
