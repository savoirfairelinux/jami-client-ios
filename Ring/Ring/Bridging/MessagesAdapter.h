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

#import <Foundation/Foundation.h>

typedef NS_ENUM(int, MessageStatus)  {
    MessageStatusUnknown = 0,
    MessageStatusSending,
    MessageStatusSent,
    MessageStatusDisplayed,
    MessageStatusFailure
};

@protocol MessagesAdapterDelegate;

@interface MessagesAdapter : NSObject

@property (class, nonatomic, weak) id <MessagesAdapterDelegate> delegate;

- (NSUInteger)sendMessageWithContent:(NSDictionary*)content withAccountId:(NSString*)accountId
                       to:(NSString*)toAccountId;

- (MessageStatus)statusForMessageId:(uint64_t)messageId;
- (void)setComposingMessageTo:(NSString*)peer
                   fromAccount:(NSString*)accountID
                   isComposing:(BOOL)isComposing;

- (void)setMessageDisplayedFrom:(NSString*)peer
                      byAccount:(NSString*)accountID
                      messageId:(NSString*)messageId
                         status:(MessageStatus)status;

@end
