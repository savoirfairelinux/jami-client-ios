//
//  RequestsAdapter.h
//  Ring
//
//  Created by kateryna on 2021-07-07.
//  Copyright © 2021 Savoir-faire Linux. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol RequestsAdapterDelegate;

@interface RequestsAdapter : NSObject

@property (class, nonatomic, weak) id <RequestsAdapterDelegate> delegate;

//conversation requests
- (NSArray<NSDictionary<NSString*,NSString*>*>*)getSwarmRequestsForAccount:(NSString*) accountId;
- (void)acceptConversationRequest:(NSString*) accountId conversationId:(NSString*) conversationId;
- (void)declineConversationRequest:(NSString*) accountId conversationId:(NSString*) conversationId;

//contact requests
- (NSArray<NSDictionary<NSString*,NSString*>*>*)trustRequestsWithAccountId:(NSString*)accountId;
- (BOOL)acceptTrustRequestFromContact:(NSString*)ringId withAccountId:(NSString*)accountId;
- (BOOL)discardTrustRequestFromContact:(NSString*)ringId withAccountId:(NSString*)accountId;

@end
