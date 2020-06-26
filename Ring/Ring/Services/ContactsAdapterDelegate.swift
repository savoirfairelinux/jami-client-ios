/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
 *
 *  Author: Silbino Gonçalves Matado <silbino.gmatado@savoirfairelinux.com>
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

@objc protocol ContactsAdapterDelegate {
    func incomingTrustRequestReceived(from senderAccount: String,
                                      to accountId: String,
                                      withPayload payload: Data,
                                      receivedDate: Date)
    func contactAdded(contact uri: String, withAccountId accountId: String, confirmed: Bool)
    func contactRemoved(contact uri: String, withAccountId accountId: String, banned: Bool)
    func profileReceived(contact uri: String, withAccountId accountId: String, vCard: String)
}
