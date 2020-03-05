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

#import "MessagesAdapter.h"

#import "Ring-Swift.h"
#import "Utils.h"
#import "dring/configurationmanager_interface.h"

@implementation MessagesAdapter

using namespace DRing;

/// Static delegate that will receive the propagated daemon events
static id <MessagesAdapterDelegate> _delegate;

#pragma mark Init
- (id)init {
    if (self = [super init]) {
        [self registerConfigurationHandler];
    }
    return self;
}
#pragma mark -

#pragma mark Callbacks registration
- (void)registerConfigurationHandler {
    std::map<std::string, std::shared_ptr<CallbackWrapperBase>> confHandlers;

    confHandlers.insert(exportable_callback<ConfigurationSignal::IncomingAccountMessage>([&](const std::string& account_id,
                                                                                             const std::string& message_id,
                                                                                             const std::string& from,
                                                                                             const std::map<std::string,
                                                                                             std::string>& payloads) {
        if (MessagesAdapter.delegate) {
            NSDictionary* message = [Utils mapToDictionnary:payloads];
            NSString* fromAccount = [NSString stringWithUTF8String:from.c_str()];
            NSString* toAccountId = [NSString stringWithUTF8String:account_id.c_str()];
            NSString* messageId = [NSString stringWithUTF8String:message_id.c_str()];
            [MessagesAdapter.delegate didReceiveMessage:message from:fromAccount messageId: messageId to:toAccountId];
        }
    }));

    confHandlers.insert(exportable_callback<ConfigurationSignal::AccountMessageStatusChanged>([&](const std::string& account_id, uint64_t message_id, const std::string& to, int state) {
        if (MessagesAdapter.delegate) {
            NSString* fromAccountId = [NSString stringWithUTF8String:account_id.c_str()];
            NSString* toUri = [NSString stringWithUTF8String:to.c_str()];
            [MessagesAdapter.delegate messageStatusChanged:(MessageStatus)state
                                                       for:message_id from:fromAccountId
                                                        to:toUri];
        }
    }));

    confHandlers.insert(exportable_callback<DebugSignal::MessageSend>([&](const std::string& message) {
        if (MessagesAdapter.delegate) {
            NSString* messageSend = [NSString stringWithUTF8String:message.c_str()];
            NSLog(@"MessageSend = %@",messageSend);
        }
    }));

    confHandlers.insert(exportable_callback<ConfigurationSignal::ComposingStatusChanged>([&](const std::string& account_id, const std::string& from, int status) {
        if (MessagesAdapter.delegate) {
            NSString* fromPeer =  [NSString stringWithUTF8String:from.c_str()];
            NSString* toAccount =  [NSString stringWithUTF8String:account_id.c_str()];
            [MessagesAdapter.delegate detectingMessageTyping:fromPeer for:toAccount status:status];
        }
    }));

    registerSignalHandlers(confHandlers);
}
#pragma mark -

- (NSUInteger)sendMessageWithContent:(NSDictionary*)content withAccountId:(NSString*)accountId
                       to:(NSString*)toAccountId {

    return (NSUInteger) sendAccountTextMessage(std::string([accountId UTF8String]),
                           std::string([toAccountId UTF8String]),
                           [Utils dictionnaryToMap:content]);
}

- (MessageStatus)statusForMessageId:(uint64_t)messageId {
    return (MessageStatus)getMessageStatus(messageId);
}

- (void)setComposingMessageTo:(NSString*)peer
                   fromAccount:(NSString*)accountID
                   isComposing:(BOOL)isComposing {
    setIsComposing(std::string([accountID UTF8String]),
                   std::string([peer UTF8String]),
                   isComposing);
}

#pragma mark AccountAdapterDelegate
+ (id <MessagesAdapterDelegate>)delegate {
    return _delegate;
}

+ (void) setDelegate:(id<MessagesAdapterDelegate>)delegate {
    _delegate = delegate;
}
#pragma mark -

@end
