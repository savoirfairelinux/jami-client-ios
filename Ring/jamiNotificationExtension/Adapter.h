/*
 *  Copyright (C) 2021 - 2022 Savoir-faire Linux Inc.
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

#import <Foundation/Foundation.h>
#import "ObjcTypes.h"

@protocol AdapterDelegate;

@interface Adapter: NSObject

@property (class, nonatomic, weak) id <AdapterDelegate> delegate;

- (void)stopForAccountId:(NSString*)accountId;
- (BOOL)start:(NSString*)accountId convId:(NSString*)convId loadAll:(BOOL)loadAll;
- (void)pushNotificationReceived:(NSString*)from message:(NSDictionary*)data;
- (bool)downloadFileWithFileId:(NSString*)fileId
                     accountId:(NSString*)accountId
                conversationId:(NSString*)conversationId
                 interactionId:(NSString*)interactionId
                  withFilePath:(NSString*)filePath;
- (NSDictionary<NSString*, NSString*>*)decrypt:(NSString*)keyPath accountId:(NSString*)accountId treated:(NSString*)treatedMessagesPath value: (NSDictionary*)value;
-(NSString*)getNameFor:(NSString*)address accountId:(NSString*)accountId;
-(NSString*)nameServerForAccountId:(NSString*)accountId;
- (NSMutableDictionary<NSString*,NSString*>*)getConversationInfoForAccount:(NSString*) accountId conversationId:(NSString*) conversationId;
- (NSArray<NSDictionary<NSString*,NSString*>*>*)getConversationMembers:(NSString*) accountId conversationId:(NSString*) conversationId;
- (NSDictionary *)getAccountDetails:(NSString *)accountID;

@end
