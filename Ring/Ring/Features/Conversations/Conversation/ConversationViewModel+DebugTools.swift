/*
 * Copyright (C) 2026 - 2026 Savoir-faire Linux Inc.
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

#if DEBUG_TOOLS_ENABLED

import Foundation

extension ConversationViewModel {
    func makeDebugToolsSendClosure() -> (String, String, String, String) -> Void {
        let conversationsService = self.conversationsService
        return { convId, accId, message, parentId in
            conversationsService.sendSwarmMessage(
                conversationId: convId,
                accountId: accId,
                message: message,
                parentId: parentId
            )
        }
    }
}

#endif
