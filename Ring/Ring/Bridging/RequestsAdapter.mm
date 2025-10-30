/*
 * Copyright (C) 2021-2025 Savoir-faire Linux Inc.
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

#import "RequestsAdapter.h"

#import "Ring-Swift.h"
#import "Utils.h"
#import "jami/configurationmanager_interface.h"
#import "jami/conversation_interface.h"

@implementation RequestsAdapter

using namespace libjami;

/// Static delegate that will receive the propagated daemon events
static id <RequestsAdapterDelegate> _delegate;

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
    confHandlers.insert(exportable_callback<ConversationSignal::ConversationRequestReceived>([&](const std::string& accountId, const std::string& conversationId, std::map<std::string, std::string> metadata) {
        if (RequestsAdapter.delegate) {
            NSString* convId =  [NSString stringWithUTF8String:conversationId.c_str()];
            NSString* account =  [NSString stringWithUTF8String:accountId.c_str()];
            NSMutableDictionary* info = [Utils mapToDictionary: metadata];
            [RequestsAdapter.delegate conversationRequestReceivedWithConversationId: convId accountId: account metadata: info];
        }
    }));

    confHandlers.insert(exportable_callback<ConfigurationSignal::IncomingTrustRequest>([&](const std::string& account_id,
                                                                               const std::string& conversationId,
                                                                               const std::string& from,
                                                                               const std::vector<uint8_t>& payload,
                                                                               time_t received) {
        if(RequestsAdapter.delegate) {
            NSString* accountId = [NSString stringWithUTF8String:account_id.c_str()];
            NSString* jamiId = [NSString stringWithUTF8String:from.c_str()];
            NSString* conversation = [NSString stringWithUTF8String:conversationId.c_str()];
            NSData* payloadData = [Utils dataFromVectorOfUInt8:payload];
            NSDate* receivedDate = [NSDate dateWithTimeIntervalSince1970:received];
            
            [RequestsAdapter.delegate incomingTrustRequestReceivedFrom: jamiId
                                                                    to:accountId
                                                        conversationId: conversation
                                                           withPayload:payloadData
                                                          receivedDate:receivedDate];
        }
    }));

    registerSignalHandlers(confHandlers);
}

#pragma mark conversation requests

- (NSArray<NSDictionary<NSString*,NSString*>*>*)getSwarmRequestsForAccount:(NSString*) accountId {
    return [Utils vectorOfMapsToArray: getConversationRequests(std::string([accountId UTF8String]))];
}
- (void)acceptConversationRequest:(NSString*) accountId conversationId:(NSString*) conversationId {
    acceptConversationRequest(std::string([accountId UTF8String]), std::string([conversationId UTF8String]));
}
- (void)declineConversationRequest:(NSString*) accountId conversationId:(NSString*) conversationId {
    declineConversationRequest(std::string([accountId UTF8String]), std::string([conversationId UTF8String]));
}

- (NSMutableDictionary<NSString*,NSString*>*)getConversationInfoForAccount:(NSString*) accountId conversationId:(NSString*) conversationId {
    return [Utils mapToDictionary: conversationInfos(std::string([accountId UTF8String]), std::string([conversationId UTF8String]))];
}

- (NSArray*)getSwarmConversationsForAccount:(NSString*) accountId {
    return [Utils vectorToArray: getConversations(std::string([accountId UTF8String]))];
}

- (NSArray<NSDictionary<NSString*,NSString*>*>*)getConversationMembers:(NSString*) accountId conversationId:(NSString*) conversationId {
    return [Utils vectorOfMapsToArray: getConversationMembers(std::string([accountId UTF8String]), std::string([conversationId UTF8String]))];
}

#pragma mark contact requests
- (NSArray<NSDictionary<NSString*,NSString*>*>*)trustRequestsWithAccountId:(NSString*)accountId {
    std::vector<std::map<std::string,std::string>> trustRequestsVector = getTrustRequests(std::string([accountId UTF8String]));
    NSArray* trustRequests = [Utils vectorOfMapsToArray:trustRequestsVector];
    return trustRequests;
}

- (NSArray<NSDictionary<NSString*,NSString*>*>*)contactsWithAccountId:(NSString*)accountId {
    std::vector<std::map<std::string, std::string>> contacts = getContacts(std::string([accountId UTF8String]));
    return [Utils vectorOfMapsToArray:contacts];
}

- (BOOL)acceptTrustRequestFromContact:(NSString*)ringId withAccountId:(NSString*)accountId {
    return acceptTrustRequest(std::string([accountId UTF8String]), std::string([ringId UTF8String]));
}

- (BOOL)discardTrustRequestFromContact:(NSString*)ringId withAccountId:(NSString*)accountId {
    return discardTrustRequest(std::string([accountId UTF8String]), std::string([ringId UTF8String]));
}

- (void)sendTrustRequestToContact:(NSString*)ringId payload:(NSData*)payloadData withAccountId:(NSString*)accountId {
    std::vector<uint8_t> payload = [Utils vectorOfUInt8FromData:payloadData];
    sendTrustRequest(std::string([accountId UTF8String]), std::string([ringId UTF8String]), payload);
}

#pragma mark RequestsAdapterDelegate
+ (id <RequestsAdapterDelegate>)delegate {
    return _delegate;
}

+ (void) setDelegate:(id<RequestsAdapterDelegate>)delegate {
    _delegate = delegate;
}

@end
