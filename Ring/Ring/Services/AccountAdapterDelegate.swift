/*
 *  Copyright (C) 2016-2019 Savoir-faire Linux Inc.
 *
 *  Author: Romain Bertozzi <romain.bertozzi@savoirfairelinux.com>
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

@objc protocol AccountAdapterDelegate {

    func accountsChanged()
    func registrationStateChanged(with response: RegistrationResponse)
    func knownDevicesChanged(for account: String, devices: [String: String])
    func exportOnRingEnded(for account: String, state: Int, pin: String)
    func deviceRevocationEnded(for account: String, state: Int, deviceId: String)
    func receivedAccountProfile(for account: String, displayName: String, photo: String)
    func migrationEnded(for account: String, status: String)
}
