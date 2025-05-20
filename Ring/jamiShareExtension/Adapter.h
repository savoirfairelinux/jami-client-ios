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

@protocol AdapterDelegate;

@interface Adapter: NSObject

@property (class, nonatomic, weak) id <AdapterDelegate> delegate;

// Delegate
+ (id<AdapterDelegate>)delegate;
+ (void)setDelegate:(id<AdapterDelegate>)delegate;

// Daemon
- (BOOL)initDaemon;
- (BOOL)startDaemon;
- (void)fini;

// Account
- (NSArray *)getAccountList;
- (void)setAccountActive:(NSString *)accountID
                  active:(bool)active;

// Conversation
- (NSArray*)getSwarmConversationsForAccount:(NSString*) accountId;
- (void)sendSwarmMessage:(NSString*)accountId conversationId:(NSString*)conversationId message:(NSString*)message parentId:(NSString*)parentId flag:(int32_t)flag;
- (void)sendSwarmFileWithName:(NSString*)displayName
                    accountId:(NSString*)accountId
               conversationId:(NSString*)conversationId
                 withFilePath:(NSString*)filePath
                       parent:(NSString*)parent;

@end
