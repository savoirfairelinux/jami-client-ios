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
#import "dring/conversation_interface.h"

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

    confHandlers.insert(exportable_callback<ConfigurationSignal::AccountMessageStatusChanged>([&](const std::string& account_id, const std::string& conversation_id, const std::string& peer, const std::string message_id, int state) {
        if (MessagesAdapter.delegate) {
        }
    }));

    confHandlers.insert(exportable_callback<ConfigurationSignal::ComposingStatusChanged>([&](const std::string& account_id, const std::string& convId, const std::string& from, int status) {
        if (MessagesAdapter.delegate) {
            NSString* fromPeer =  [NSString stringWithUTF8String:from.c_str()];
            NSString* toAccount =  [NSString stringWithUTF8String:account_id.c_str()];
            [MessagesAdapter.delegate detectingMessageTyping:fromPeer for:toAccount status:status];
        }
    }));
    
    confHandlers.insert(exportable_callback<ConversationSignal::ConversationLoaded>([&](uint32_t id, const std::string& accountId, const std::string& conversationId, std::vector<std::map<std::string, std::string>> messages) {
        if (MessagesAdapter.delegate) {
            NSString* convId =  [NSString stringWithUTF8String:conversationId.c_str()];
            NSString* account =  [NSString stringWithUTF8String:accountId.c_str()];
            NSArray* interactions = [Utils vectorOfMapsToArray: messages];
            [MessagesAdapter.delegate conversationLoadedWithConversationId: convId accountId: account messages: interactions];
        }
    }));
    
    confHandlers.insert(exportable_callback<ConversationSignal::MessageReceived>([&](const std::string& accountId, const std::string& conversationId, std::map<std::string, std::string> message) {
        if (MessagesAdapter.delegate) {
            NSString* convId =  [NSString stringWithUTF8String:conversationId.c_str()];
            NSString* account =  [NSString stringWithUTF8String:accountId.c_str()];
            NSMutableDictionary* interaction = [Utils mapToDictionnary: message];
            [MessagesAdapter.delegate newInteractionWithConversationId: convId accountId: account message: interaction];
        }
    }));
    
    confHandlers.insert(exportable_callback<ConversationSignal::ConversationReady>([&](const std::string& accountId, const std::string& conversationId) {
        if (MessagesAdapter.delegate) {
            NSString* convId =  [NSString stringWithUTF8String:conversationId.c_str()];
            NSString* account =  [NSString stringWithUTF8String:accountId.c_str()];
            [MessagesAdapter.delegate conversationReadyWithConversationId: convId accountId: account];
        }
    }));
    
    confHandlers.insert(exportable_callback<ConversationSignal::ConversationRemoved>([&](const std::string& accountId, const std::string& conversationId) {
        if (MessagesAdapter.delegate) {
        }
    }));
    /* event 0 = add, 1 = joins, 2 = leave, 3 = banned */
    confHandlers.insert(exportable_callback<ConversationSignal::ConversationMemberEvent>([&](const std::string& accountId, const std::string& conversationId, const std::string& memberUri, int event) {
        if (MessagesAdapter.delegate) {
        }
    }));
    
    confHandlers.insert(exportable_callback<ConversationSignal::OnConversationError>([&](const std::string& accountId, const std::string& conversationId, int code, const std::string& what) {
        if (MessagesAdapter.delegate) {
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

- (void)setMessageDisplayedFrom:(NSString*)peer
                      byAccount:(NSString*)accountID
                      messageId:(NSString*)messageId
                         status:(MessageStatus)status {
    setMessageDisplayed(std::string([accountID UTF8String]),
                        std::string([peer UTF8String]),
                        std::string([messageId UTF8String]),
                        status);
}

- (NSArray*)getSwarmConversationsForAccount:(NSString*) accountId {
    return [Utils vectorToArray: getConversations(std::string([accountId UTF8String]))];
}

- (uint32_t)loadConversationMessages:(NSString*) accountId conversationId:(NSString*) conversationId from:(NSString*)fromMessage size:(NSInteger)size {
    return loadConversationMessages(std::string([accountId UTF8String]), std::string([conversationId UTF8String]), std::string([fromMessage UTF8String]), size);
}

- (NSMutableDictionary*)getConversationInfoForAccount:(NSString*) accountId conversationId:(NSString*) conversationId {
    return [Utils mapToDictionnary: conversationInfos(std::string([accountId UTF8String]), std::string([conversationId UTF8String]))];
}

- (NSArray*)getConversationMembers:(NSString*) accountId conversationId:(NSString*) conversationId {
    return [Utils vectorOfMapsToArray: getConversationMembers(std::string([accountId UTF8String]), std::string([conversationId UTF8String]))];
}

- (void)removeConversation:(NSString*) accountId conversationId:(NSString*) conversationId {
    removeConversation(std::string([accountId UTF8String]), std::string([conversationId UTF8String]));
}

- (NSString*)startConversation:(NSString*) accountId {
    return [NSString stringWithUTF8String: startConversation(std::string([accountId UTF8String])).c_str()];
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
