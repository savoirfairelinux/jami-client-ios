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
    MessageStatusFailure,
    MessageStatusCanceled
};

@interface SwarmMessageWrap : NSObject

@property (nonatomic, strong) NSString* id;
@property (nonatomic, strong) NSString* type;
@property (nonatomic, strong) NSString* linearizedParent;
@property (nonatomic, strong) NSDictionary<NSString *, NSString *>* body;
@property (nonatomic, strong) NSArray<NSDictionary<NSString *, NSString *> *>* reactions;
@property (nonatomic, strong) NSArray<NSDictionary<NSString *, NSString *> *>* editions;
@property (nonatomic, strong) NSDictionary<NSString *, NSNumber* >* status;

@end

@protocol MessagesAdapterDelegate;

@interface ConversationsAdapter : NSObject

@property (class, nonatomic, weak) id <MessagesAdapterDelegate> messagesDelegate;

- (NSUInteger)sendMessageWithContent:(NSDictionary*)content withAccountId:(NSString*)accountId
                       to:(NSString*)toAccountId flag:(int)flag;

- (void)setComposingMessageTo:(NSString*)peer
                   fromAccount:(NSString*)accountID
                   isComposing:(BOOL)isComposing;

- (void)setMessageDisplayedFrom:(NSString*)conversationUri
                      byAccount:(NSString*)accountID
                      messageId:(NSString*)messageId
                         status:(MessageStatus)status;
- (uint32_t)countInteractions:(NSString*)accountId conversationId:(NSString*)conversationId from:(NSString*)messageFrom to:(NSString*)messsageTo authorUri:(NSString*)authorUri;
- (NSArray*)getSwarmConversationsForAccount:(NSString*) accountId;

- (NSMutableDictionary<NSString*,NSString*>*)getConversationInfoForAccount:(NSString*) accountId conversationId:(NSString*) conversationId;

- (NSMutableDictionary<NSString*,NSString*>*)getConversationPreferencesForAccount:(NSString*)accountId conversationId:(NSString*)conversationId;

- (void)updateConversationInfosFor:(NSString*)accountId conversationId:(NSString*)conversationId infos:(NSDictionary<NSString*,NSString*>*)infos;

- (void)updateConversationPreferencesFor:(NSString*)accountId conversationId:(NSString*)conversationId prefs:(NSDictionary<NSString*,NSString*>*)prefs;

- (NSArray<NSDictionary<NSString*,NSString*>*>*)getConversationMembers:(NSString*)accountId conversationId:(NSString*)conversationId;

- (void)addConversationMemberFor:(NSString*)accountId conversationId:(NSString*)conversationId memberId:(NSString*)memberId;

- (void)removeConversationMemberFor:(NSString*)accountId conversationId:(NSString*)conversationId memberId:(NSString*)memberId;

- (void)removeConversation:(NSString*) accountId conversationId:(NSString*) conversationId;

- (NSString*)startConversation:(NSString*) accountId;
- (uint32_t)loadConversationMessages:(NSString*) accountId conversationId:(NSString*) conversationId from:(NSString*)fromMessage size:(NSInteger)size;

- (uint32_t)loadConversationForAccountId:(NSString*) accountId conversationId:(NSString*) conversationId from:(NSString*)fromMessage until:(NSString*)toMessage;

- (void)sendSwarmMessage:(NSString*)accountId conversationId:(NSString*)conversationId message:(NSString*)message parentId:(NSString*)parentId flag:(int32_t)flag;
- (void)reloadConversationsAndRequests:(NSString*)accountId;
- (void)clearCasheForConversationId:(NSString*)conversationId
                          accountId:(NSString*)accountId;
@end
