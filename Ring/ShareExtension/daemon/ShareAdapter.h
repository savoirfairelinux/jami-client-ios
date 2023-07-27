/*
 * Copyright (C) 2023 Savoir-faire Linux Inc. *
 *
 * Author: Alireza Toghiani Khorasgani alireza.toghiani@savoirfairelinux.com
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version. *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details. *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

#import <Foundation/Foundation.h>

@protocol NameRegistrationAdapterDelegate;

@interface ShareAdapter: NSObject

@property (class, nonatomic, weak) id <NameRegistrationAdapterDelegate> delegate;

- (void)lookupNameWithAccount:(NSString*)account nameserver:(NSString*)nameserver
                         name:(NSString*)name;

- (void)registerNameWithAccount:(NSString*)account password:(NSString*)password
                           name:(NSString*)name;

- (void)lookupAddressWithAccount:(NSString*)account nameserver:(NSString*)nameserver
                         address:(NSString*)address;

- (void)searchUserWithAccount:(NSString*)account query:(NSString*)query;

- (BOOL)start;
- (void)stop;

- (NSArray *)getAccountList;

- (NSArray*)getSwarmConversationsForAccount:(NSString*) accountId;
- (NSMutableDictionary<NSString*,NSString*>*)getConversationInfoForAccount:(NSString*) accountId conversationId:(NSString*) conversationId;
- (NSArray<NSDictionary<NSString*,NSString*>*>*)getConversationMembers:(NSString*)accountId conversationId:(NSString*)conversationId;

@end
