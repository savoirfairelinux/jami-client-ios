/*
 *  Copyright (C) 2017 Savoir-faire Linux Inc.
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

import RxSwift

class MessageViewModel {

    fileprivate let accountService = AppDelegate.accountService

    fileprivate var message :MessageModel

    init(withMessage message: MessageModel) {
        self.message = message
    }

    var content: String {
        return self.message.content
    }

    func bubblePosition() -> BubblePosition {

        let accountUsernameKey = ConfigKeyModel(withKey: ConfigKey.AccountUsername)
        
        if "ring:".appending(self.message.author) == accountService.currentAccount?.details?.get(withConfigKeyModel: accountUsernameKey) {
            return .sent
        } else {
            return .received
        }
    }
}
