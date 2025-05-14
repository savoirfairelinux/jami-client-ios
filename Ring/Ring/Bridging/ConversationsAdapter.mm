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

#import "ConversationsAdapter.h"

#import "Ring-Swift.h"
#import "Utils.h"
#import "jami/configurationmanager_interface.h"
#import "jami/conversation_interface.h"

@implementation SwarmMessageWrap

- (instancetype)initWithSwarmMessage:(const libjami::SwarmMessage &)message {
    self = [super init];
    if (self) {
        self.id = @(message.id.c_str());
        self.type = @(message.type.c_str());
        self.linearizedParent = @(message.linearizedParent.c_str());
        self.body = [Utils mapToDictionnary: message.body];
        self.reactions = [Utils vectorOfMapsToArray: message.reactions];
        self.editions = [Utils vectorOfMapsToArray: message.editions];
        self.status = [Utils mapToDictionnaryWithInt: message.status];
    }
    return self;
}

@end

@implementation ConversationsAdapter

using namespace libjami;

/// Static delegate that will receive the propagated daemon events
static id <MessagesAdapterDelegate> _messagesDelegate;

#pragma mark Init
- (id)init {
    if (self = [super init]) {
        [self registerConfigurationHandler];
    }
    return self;
}

#pragma mark Callbacks registration
- (void)registerConfigurationHandler {
    std::map<std::string, std::shared_ptr<CallbackWrapperBase>> confHandlers;
    /// interactions signals
    confHandlers.insert(exportable_callback<ConfigurationSignal::IncomingAccountMessage>([&](const std::string& account_id,
                                                                                             const std::string& from,
                                                                                             const std::string& message_id,
                                                                                             const std::map<std::string,
                                                                                             std::string>& payloads) {
        if (ConversationsAdapter.messagesDelegate) {
            NSDictionary* message = [Utils mapToDictionnary:payloads];
            NSString* fromAccount = [NSString stringWithUTF8String:from.c_str()];
            NSString* toAccountId = [NSString stringWithUTF8String:account_id.c_str()];
            NSString* messageId = [NSString stringWithUTF8String:message_id.c_str()];
            [ConversationsAdapter.messagesDelegate didReceiveMessage:message from:fromAccount messageId: messageId to:toAccountId];
        }
    }));

    confHandlers.insert(exportable_callback<ConfigurationSignal::AccountMessageStatusChanged>([&](const std::string& account_id, const std::string& conversation_id, const std::string& peer, const std::string message_id, int state) {
        if (ConversationsAdapter.messagesDelegate) {
            NSString* accountId = [NSString stringWithUTF8String:account_id.c_str()];
            NSString* conversationId = [NSString stringWithUTF8String:conversation_id.c_str()];
            NSString* jamiId = [NSString stringWithUTF8String:peer.c_str()];
            NSString* messageId = [NSString stringWithUTF8String:message_id.c_str()];
            [ConversationsAdapter.messagesDelegate messageStatusChanged:(MessageStatus)state for:messageId from:accountId to:jamiId in: conversationId];
        }
    }));

    confHandlers.insert(exportable_callback<ConfigurationSignal::ComposingStatusChanged>([&](const std::string& account_id, const std::string& convId, const std::string& from, int status) {
        if (ConversationsAdapter.messagesDelegate) {
            NSString* fromPeer = [NSString stringWithUTF8String:from.c_str()];
            NSString* toAccount = [NSString stringWithUTF8String:account_id.c_str()];
            NSString* conversationId = [NSString stringWithUTF8String:convId.c_str()];

            [ConversationsAdapter.messagesDelegate composingStatusChangedWithAccountId:toAccount
                                                                   conversationId:conversationId
                                                                              from:fromPeer
                                                                             status:status];
        }
    }));

    confHandlers.insert(exportable_callback<ConversationSignal::SwarmLoaded>([&](uint32_t id, const std::string& accountId, const std::string& conversationId, std::vector<libjami::SwarmMessage> messages) {
        if (ConversationsAdapter.messagesDelegate) {
            NSString* convId =  [NSString stringWithUTF8String:conversationId.c_str()];
            NSString* account =  [NSString stringWithUTF8String:accountId.c_str()];

            NSMutableArray<SwarmMessageWrap *> *swarmMessages = [[NSMutableArray alloc] init];
            for (const libjami::SwarmMessage &message : messages) {
                SwarmMessageWrap *swarmMessage = [[SwarmMessageWrap alloc] initWithSwarmMessage:message];
                [swarmMessages addObject:swarmMessage];
            }
            [ConversationsAdapter.messagesDelegate conversationLoadedWithConversationId: convId accountId: account messages: swarmMessages requestId: id];
        }
    }));

    confHandlers.insert(exportable_callback<ConversationSignal::ReactionAdded>([&](const std::string& accountId, const std::string& conversationId, const std::string& messageId, std::map<std::string, std::string> reaction) {
        if (ConversationsAdapter.messagesDelegate) {
            NSString* conversationIdStr =  [NSString stringWithUTF8String:conversationId.c_str()];
            NSString* accountIdStr =  [NSString stringWithUTF8String:accountId.c_str()];
            NSString* messageIdStr =  [NSString stringWithUTF8String:messageId.c_str()];
            NSDictionary* reactionDict = [Utils mapToDictionnary: reaction];
            [ConversationsAdapter.messagesDelegate reactionAddedWithConversationId:conversationIdStr accountId:accountIdStr messageId:messageIdStr reaction:reactionDict];
        }
    }));

    confHandlers.insert(exportable_callback<ConversationSignal::ReactionRemoved>([&](const std::string& accountId, const std::string& conversationId, const std::string& messageId, const std::string& reactionId) {
                if (ConversationsAdapter.messagesDelegate) {
                    NSString* conversationIdStr =  [NSString stringWithUTF8String:conversationId.c_str()];
                    NSString* accountIdStr =  [NSString stringWithUTF8String:accountId.c_str()];
                    NSString* messageIdStr =  [NSString stringWithUTF8String:messageId.c_str()];
                    NSString* reactionIdStr =  [NSString stringWithUTF8String:reactionId.c_str()];
                    [ConversationsAdapter.messagesDelegate reactionRemovedWithConversationId:conversationIdStr accountId:accountIdStr messageId:messageIdStr reactionId:reactionIdStr];
                }
    }));

    confHandlers.insert(exportable_callback<ConversationSignal::ConversationLoaded>([&](uint32_t id, const std::string& accountId, const std::string& conversationId, std::vector<std::map<std::string, std::string>> messages) {
            if (ConversationsAdapter.messagesDelegate) {
                    NSString* convId =  [NSString stringWithUTF8String:conversationId.c_str()];
                    NSString* account =  [NSString stringWithUTF8String:accountId.c_str()];
                    NSArray* interactions = [Utils vectorOfMapsToArray: messages];
                [ConversationsAdapter.messagesDelegate messageLoadedWithConversationId:convId accountId: account messages:interactions];
            }
        }));

    confHandlers.insert(exportable_callback<ConversationSignal::SwarmMessageReceived>([&](const std::string& accountId, const std::string& conversationId, libjami::SwarmMessage message) {
        if (ConversationsAdapter.messagesDelegate) {
            NSString* convId =  [NSString stringWithUTF8String:conversationId.c_str()];
            NSString* account =  [NSString stringWithUTF8String:accountId.c_str()];
            SwarmMessageWrap *swarmMessage = [[SwarmMessageWrap alloc] initWithSwarmMessage: message];
            [ConversationsAdapter.messagesDelegate newInteractionWithConversationId: convId accountId: account message: swarmMessage];
        }
    }));

    /// conversations signals
    confHandlers.insert(exportable_callback<ConversationSignal::ConversationReady>([&](const std::string& accountId, const std::string& conversationId) {
        if (ConversationsAdapter.messagesDelegate) {
            NSString* convId =  [NSString stringWithUTF8String:conversationId.c_str()];
            NSString* account =  [NSString stringWithUTF8String:accountId.c_str()];
            [ConversationsAdapter.messagesDelegate conversationReadyWithConversationId: convId accountId: account];
        }
    }));

    confHandlers.insert(exportable_callback<ConversationSignal::ConversationRemoved>([&](const std::string& account_id, const std::string& conversation_id) {
        if (ConversationsAdapter.messagesDelegate) {
            NSString* conversationId = [NSString stringWithUTF8String:conversation_id.c_str()];
            NSString* accountId = [NSString stringWithUTF8String:account_id.c_str()];
            [ConversationsAdapter.messagesDelegate conversationRemovedWithConversationId:conversationId accountId:accountId];
        }
    }));

    confHandlers.insert(exportable_callback<ConversationSignal::ConversationRequestDeclined>([&](const std::string& account_id, const std::string& conversation_id) {
        if (ConversationsAdapter.messagesDelegate) {
            NSString* conversationId = [NSString stringWithUTF8String:conversation_id.c_str()];
            NSString* accountId = [NSString stringWithUTF8String:account_id.c_str()];
            [ConversationsAdapter.messagesDelegate conversationDeclinedWithConversationId:conversationId accountId:accountId];
        }
    }));

    /* event 0 = add, 1 = joins, 2 = leave, 3 = banned */
    confHandlers.insert(exportable_callback<ConversationSignal::ConversationMemberEvent>([&](const std::string& account_id, const std::string& conversation_id, const std::string& member_uri, int event) {
        if (ConversationsAdapter.messagesDelegate) {
            NSString* conversationId = [NSString stringWithUTF8String:conversation_id.c_str()];
            NSString* accountId = [NSString stringWithUTF8String:account_id.c_str()];
            NSString* memberURI = [NSString stringWithUTF8String:member_uri.c_str()];
            [ConversationsAdapter.messagesDelegate conversationMemberEventWithConversationId:conversationId accountId:accountId memberUri:memberURI event:event];
        }
    }));

    confHandlers.insert(exportable_callback<ConversationSignal::OnConversationError>([&](const std::string& accountId, const std::string& conversationId, int code, const std::string& what) {
        if (ConversationsAdapter.messagesDelegate) {
        }
    }));

    confHandlers.insert(exportable_callback<ConversationSignal::ConversationProfileUpdated>([&](const std::string& accountId, const std::string& conversationId, std::map<std::string, std::string> profile) {
        if (ConversationsAdapter.messagesDelegate) {
            NSString* convId =  [NSString stringWithUTF8String:conversationId.c_str()];
            NSString* account =  [NSString stringWithUTF8String:accountId.c_str()];
            NSMutableDictionary* profileDictionary = [Utils mapToDictionnary: profile];
            [ConversationsAdapter.messagesDelegate conversationProfileUpdatedWithConversationId:convId accountId:account profile:profileDictionary];
        }
    }));

    confHandlers.insert(exportable_callback<ConversationSignal::ConversationPreferencesUpdated>([&](const std::string& accountId, const std::string& conversationId, std::map<std::string, std::string> preferences) {
        if (ConversationsAdapter.messagesDelegate) {
            NSString* convId =  [NSString stringWithUTF8String:conversationId.c_str()];
            NSString* account =  [NSString stringWithUTF8String:accountId.c_str()];
            NSMutableDictionary* preferencesDictionary = [Utils mapToDictionnary: preferences];
            [ConversationsAdapter.messagesDelegate conversationPreferencesUpdatedWithConversationId:convId accountId:account preferences: preferencesDictionary];
        }
    }));

    confHandlers.insert(exportable_callback<ConversationSignal::SwarmMessageUpdated>([&](const std::string& accountId, const std::string& conversationId, libjami::SwarmMessage message) {
        if (ConversationsAdapter.messagesDelegate) {
            NSString* convIdStr =  [NSString stringWithUTF8String:conversationId.c_str()];
            NSString* accountIdStr =  [NSString stringWithUTF8String:accountId.c_str()];
            SwarmMessageWrap *swarmMessage = [[SwarmMessageWrap alloc] initWithSwarmMessage: message];
            [ConversationsAdapter.messagesDelegate messageUpdatedWithConversationId:convIdStr accountId:accountIdStr message:swarmMessage];
        }
    }));
    registerSignalHandlers(confHandlers);
}

#pragma mark interactions

- (NSUInteger)sendMessageWithContent:(NSDictionary*)content withAccountId:(NSString*)accountId
                       to:(NSString*)toAccountId flag:(int)flag {

    return (NSUInteger) sendAccountTextMessage(std::string([accountId UTF8String]),
                           std::string([toAccountId UTF8String]),
                           [Utils dictionnaryToMap:content], flag);
}

- (void)setComposingMessageTo:(NSString*)conversationUri
                   fromAccount:(NSString*)accountID
                   isComposing:(BOOL)isComposing {
    setIsComposing(std::string([accountID UTF8String]),
                   std::string([conversationUri UTF8String]),
                   isComposing);
}

- (void)setMessageDisplayedFrom:(NSString*)conversationUri
                      byAccount:(NSString*)accountID
                      messageId:(NSString*)messageId
                         status:(MessageStatus)status {
    setMessageDisplayed(std::string([accountID UTF8String]),
                        std::string([conversationUri UTF8String]),
                        std::string([messageId UTF8String]),
                        status);
}

- (uint32_t)loadConversationMessages:(NSString*) accountId conversationId:(NSString*) conversationId from:(NSString*)fromMessage size:(NSInteger)size {
    return loadConversation(std::string([accountId UTF8String]), std::string([conversationId UTF8String]), std::string([fromMessage UTF8String]), size);
}

- (uint32_t)loadConversationForAccountId:(NSString*) accountId conversationId:(NSString*) conversationId from:(NSString*)fromMessage until:(NSString*)toMessage {
    return loadSwarmUntil(std::string([accountId UTF8String]), std::string([conversationId UTF8String]), std::string([fromMessage UTF8String]), std::string([toMessage UTF8String]));
}

- (void)sendSwarmMessage:(NSString*)accountId conversationId:(NSString*)conversationId message:(NSString*)message parentId:(NSString*)parentId flag:(int32_t)flag {
    sendMessage(std::string([accountId UTF8String]), std::string([conversationId UTF8String]), std::string([message UTF8String]), std::string([parentId UTF8String]), flag);
}

- (uint32_t)countInteractions:(NSString*)accountId conversationId:(NSString*)conversationId from:(NSString*)messageFrom to:(NSString*)messsageTo authorUri:(NSString*)authorUri  {
    return countInteractions(std::string([accountId UTF8String]), std::string([conversationId UTF8String]), std::string([messageFrom UTF8String]), std::string([messsageTo UTF8String]), std::string([authorUri UTF8String]));
}

#pragma mark conversations

- (NSMutableDictionary<NSString*,NSString*>*)getConversationInfoForAccount:(NSString*) accountId conversationId:(NSString*) conversationId {
    return [Utils mapToDictionnary: conversationInfos(std::string([accountId UTF8String]), std::string([conversationId UTF8String]))];
}

- (NSMutableDictionary<NSString*,NSString*>*)getConversationPreferencesForAccount:(NSString*)accountId conversationId:(NSString*)conversationId {
    return [Utils mapToDictionnary: getConversationPreferences(std::string([accountId UTF8String]), std::string([conversationId UTF8String]))];
}

- (void)updateConversationInfosFor:(NSString*)accountId conversationId:(NSString*)conversationId infos:(NSDictionary<NSString*,NSString*>*)infos {
    updateConversationInfos(std::string([accountId UTF8String]), std::string([conversationId UTF8String]), [Utils dictionnaryToMap: infos]);
}

- (void)updateConversationPreferencesFor:(NSString*)accountId conversationId:(NSString*)conversationId prefs:(NSDictionary<NSString*,NSString*>*)prefs {
    setConversationPreferences(std::string([accountId UTF8String]), std::string([conversationId UTF8String]), [Utils dictionnaryToMap: prefs]);
}

- (NSArray*)getSwarmConversationsForAccount:(NSString*) accountId {
    return [Utils vectorToArray: getConversations(std::string([accountId UTF8String]))];
}

- (NSArray<NSDictionary<NSString*,NSString*>*>*)getConversationMembers:(NSString*) accountId conversationId:(NSString*) conversationId {
    return [Utils vectorOfMapsToArray: getConversationMembers(std::string([accountId UTF8String]), std::string([conversationId UTF8String]))];
}

- (void)addConversationMemberFor:(NSString*)accountId conversationId:(NSString*)conversationId memberId:(NSString*)memberId {
    libjami::addConversationMember(std::string([accountId UTF8String]), std::string([conversationId UTF8String]), std::string([memberId UTF8String]));
}

- (void)removeConversationMemberFor:(NSString*)accountId conversationId:(NSString*)conversationId memberId:(NSString*)memberId {
    libjami::removeConversationMember(std::string([accountId UTF8String]), std::string([conversationId UTF8String]), std::string([memberId UTF8String]));
}

- (void)removeConversation:(NSString*) accountId conversationId:(NSString*) conversationId {
    removeConversation(std::string([accountId UTF8String]), std::string([conversationId UTF8String]));
}

- (NSString*)startConversation:(NSString*) accountId {
    return [NSString stringWithUTF8String: startConversation(std::string([accountId UTF8String])).c_str()];
}

- (void)reloadConversationsAndRequests:(NSString*)accountId {
    reloadConversationsAndRequests(std::string([accountId UTF8String]));
}

- (void)clearCasheForConversationId:(NSString*)conversationId
                          accountId:(NSString*)accountId {
    clearCache(std::string([accountId UTF8String]), std::string([conversationId UTF8String]));
}

#pragma mark MessagesAdapterDelegate
+ (id <MessagesAdapterDelegate>)messagesDelegate {
    return _messagesDelegate;
}

+ (void) setMessagesDelegate:(id<MessagesAdapterDelegate>)delegate {
    _messagesDelegate = delegate;
}

@end
