/*
 *  Copyright (C) 2025-2025 Savoir-faire Linux Inc.
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

@objc
protocol AdapterDelegate {
    func dataTransferEvent(withFileId transferId: String, withEventCode eventCode: Int, accountId: String, conversationId: String, interactionId: String)
    func newInteraction(conversationId: String, accountId: String, message: SwarmMessageWrap)
    func messageStatusChanged(_ status: MessageStatus, for messageId: String, from accountId: String, to jamiId: String, in conversationId: String)
    func registeredNameFound(with response: LookupNameResponse)
    func registrationStateChanged(for accountId: String, state: String)
}
