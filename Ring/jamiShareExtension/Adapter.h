/*
 *  Copyright (C) 2025-2025 Savoir-faire Linux Inc.
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

#import "ObjcTypes.h"
#import "LookupNameResponse.h"
#import <Foundation/Foundation.h>

@protocol AdapterDelegate;

@interface Adapter: NSObject

@property (class, nonatomic, weak) id <AdapterDelegate> delegate;

+ (id<AdapterDelegate>)delegate;
+ (void)setDelegate:(id<AdapterDelegate>)delegate;

- (BOOL)initDaemon;
- (BOOL)startDaemon;
- (void)cleanup;

- (NSArray *)getAccountList;
- (void)setAccountActive:(NSString *)accountID
                  active:(bool)active;

- (NSArray*)getSwarmConversationsForAccount:(NSString*) accountId;
- (void)sendSwarmMessage:(NSString*)accountId conversationId:(NSString*)conversationId message:(NSString*)message parentId:(NSString*)parentId flag:(int32_t)flag;
- (void)sendSwarmFileWithName:(NSString*)displayName
                    accountId:(NSString*)accountId
               conversationId:(NSString*)conversationId
                 withFilePath:(NSString*)filePath
                       parent:(NSString*)parent;

- (NSDataTransferError) dataTransferInfoWithId:(NSString*)fileId
                                          accountId:(NSString*)accountId
                                           withInfo:(NSDataTransferInfo*)info;

- (void)lookupAddressWithAccount:(NSString*)account nameserver:(NSString*)nameserver
                         address:(NSString*)address;

- (NSDictionary *)getAccountDetails:(NSString *)accountID;

- (NSMutableDictionary<NSString*,NSString*>*)getConversationInfoForAccount:(NSString*) accountId conversationId:(NSString*) conversationId;

- (NSArray<NSDictionary<NSString*,NSString*>*>*)getConversationMembers:(NSString*) accountId conversationId:(NSString*) conversationId;

- (void)pushNotificationReceived:(NSString *) from message:(NSDictionary*) data;

@end
