/*
 *  Copyright (C) 2021 Savoir-faire Linux Inc.
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

#import "RequestsAdapter.h"

#import "Ring-Swift.h"
#import "Utils.h"
#import "dring/configurationmanager_interface.h"
#import "dring/conversation_interface.h"

@implementation RequestsAdapter

using namespace DRing;

/// Static delegate that will receive the propagated daemon events
static id <RequestsAdapterDelegate> _delegate;

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
    confHandlers.insert(exportable_callback<ConversationSignal::ConversationRequestReceived>([&](const std::string& accountId, const std::string& conversationId, std::map<std::string, std::string> metadata) {
        if (RequestsAdapter.delegate) {
            NSString* convId =  [NSString stringWithUTF8String:conversationId.c_str()];
            NSString* account =  [NSString stringWithUTF8String:accountId.c_str()];
            NSMutableDictionary* info = [Utils mapToDictionnary: metadata];
            [RequestsAdapter.delegate conversationRequestReceivedWithConversationId: convId accountId: account metadata: info];
        }
    }));
    
    confHandlers.insert(exportable_callback<ConfigurationSignal::IncomingTrustRequest>([&](const std::string& account_id,
                                                                               const std::string& from,
                                                                               const std::string& conversationId,
                                                                               const std::vector<uint8_t>& payload,
                                                                               time_t received) {
        if(RequestsAdapter.delegate) {
            NSString* accountId = [NSString stringWithUTF8String:account_id.c_str()];
            NSString* senderAccount = [NSString stringWithUTF8String:from.c_str()];
            NSData* payloadData = [Utils dataFromVectorOfUInt8:payload];
            NSDate* receivedDate = [NSDate dateWithTimeIntervalSince1970:received];
            
            [RequestsAdapter.delegate incomingTrustRequestReceivedFrom:senderAccount
                                                                    to:accountId
                                                           withPayload:payloadData
                                                          receivedDate:receivedDate];
        }
    }));

    registerSignalHandlers(confHandlers);
}

//conversations requests

- (NSArray<NSDictionary<NSString*,NSString*>*>*)getSwarmRequestsForAccount:(NSString*) accountId {
    return [Utils vectorOfMapsToArray: getConversationRequests(std::string([accountId UTF8String]))];
}
- (void)acceptConversationRequest:(NSString*) accountId conversationId:(NSString*) conversationId {
    acceptConversationRequest(std::string([accountId UTF8String]), std::string([conversationId UTF8String]));
}
- (void)declineConversationRequest:(NSString*) accountId conversationId:(NSString*) conversationId {
    declineConversationRequest(std::string([accountId UTF8String]), std::string([conversationId UTF8String]));
}

//contact requests
- (NSArray<NSDictionary<NSString*,NSString*>*>*)trustRequestsWithAccountId:(NSString*)accountId {
    std::vector<std::map<std::string,std::string>> trustRequestsVector = getTrustRequests(std::string([accountId UTF8String]));
    NSArray* trustRequests = [Utils vectorOfMapsToArray:trustRequestsVector];
    return trustRequests;
}

- (BOOL)acceptTrustRequestFromContact:(NSString*)ringId withAccountId:(NSString*)accountId {
    return acceptTrustRequest(std::string([accountId UTF8String]), std::string([ringId UTF8String]));
}

- (BOOL)discardTrustRequestFromContact:(NSString*)ringId withAccountId:(NSString*)accountId {
    return discardTrustRequest(std::string([accountId UTF8String]), std::string([ringId UTF8String]));
}
//#pragma mark -
//
//- (NSUInteger)sendMessageWithContent:(NSDictionary*)content withAccountId:(NSString*)accountId
//                       to:(NSString*)toAccountId {
//
//    return (NSUInteger) sendAccountTextMessage(std::string([accountId UTF8String]),
//                           std::string([toAccountId UTF8String]),
//                           [Utils dictionnaryToMap:content]);
//}
//
//- (MessageStatus)statusForMessageId:(uint64_t)messageId {
//    return (MessageStatus)getMessageStatus(messageId);
//}
//
//- (void)setComposingMessageTo:(NSString*)peer
//                   fromAccount:(NSString*)accountID
//                   isComposing:(BOOL)isComposing {
//    setIsComposing(std::string([accountID UTF8String]),
//                   std::string([peer UTF8String]),
//                   isComposing);
//}
//
//- (void)setMessageDisplayedFrom:(NSString*)peer
//                      byAccount:(NSString*)accountID
//                      messageId:(NSString*)messageId
//                         status:(MessageStatus)status {
//    setMessageDisplayed(std::string([accountID UTF8String]),
//                        std::string([peer UTF8String]),
//                        std::string([messageId UTF8String]),
//                        status);
//}
//
//- (NSArray*)getSwarmConversationsForAccount:(NSString*) accountId {
//    return [Utils vectorToArray: getConversations(std::string([accountId UTF8String]))];
//}
//
//- (NSArray*)getSwarmRequestsForAccount:(NSString*) accountId {
//    return [Utils vectorOfMapsToArray: getConversationRequests(std::string([accountId UTF8String]))];
//}
//
//- (uint32_t)loadConversationMessages:(NSString*) accountId conversationId:(NSString*) conversationId from:(NSString*)fromMessage size:(NSInteger)size {
//    return loadConversationMessages(std::string([accountId UTF8String]), std::string([conversationId UTF8String]), std::string([fromMessage UTF8String]), size);
//}
//
//- (NSMutableDictionary*)getConversationInfoForAccount:(NSString*) accountId conversationId:(NSString*) conversationId {
//    return [Utils mapToDictionnary: conversationInfos(std::string([accountId UTF8String]), std::string([conversationId UTF8String]))];
//}
//
//- (NSArray*)getConversationMembers:(NSString*) accountId conversationId:(NSString*) conversationId {
//    return [Utils vectorOfMapsToArray: getConversationMembers(std::string([accountId UTF8String]), std::string([conversationId UTF8String]))];
//}
//- (void)acceptConversationRequest:(NSString*) accountId conversationId:(NSString*) conversationId {
//    acceptConversationRequest(std::string([accountId UTF8String]), std::string([conversationId UTF8String]));
//}
//- (void)declineConversationRequest:(NSString*) accountId conversationId:(NSString*) conversationId {
//    declineConversationRequest(std::string([accountId UTF8String]), std::string([conversationId UTF8String]));
//}
//
//- (void)removeConversation:(NSString*) accountId conversationId:(NSString*) conversationId {
//    removeConversation(std::string([accountId UTF8String]), std::string([conversationId UTF8String]));
//}
//
//- (NSString*)startConversation:(NSString*) accountId {
//    return [NSString stringWithUTF8String: startConversation(std::string([accountId UTF8String])).c_str()];
//}

#pragma mark RequestsAdapterDelegate
+ (id <RequestsAdapterDelegate>)delegate {
    return _delegate;
}

+ (void) setDelegate:(id<RequestsAdapterDelegate>)delegate {
    _delegate = delegate;
}
#pragma mark -

@end
