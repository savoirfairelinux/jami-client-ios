/*
 *  Copyright (C) 2017 Savoir-faire Linux Inc.
 *
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
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

typealias Profile = (
    id: Int64,
    uri: String,
    alias: String?,
    photo: String?,
    type: String,
    status: String
)

typealias Conversation = (
    id: Int64,
    participantID: Int64
)

typealias Interaction = (
    id: Int64,
    accountID: Int64,
    authorID: Int64,
    conversationID: Int64,
    timestamp: Int64,
    body: String,
    type: String,
    status: String,
    daemonID: String
)
