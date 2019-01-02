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

@protocol ContactsAdapterDelegate;

@interface ContactsAdapter : NSObject

@property (class, nonatomic, weak) id <ContactsAdapterDelegate> delegate;

//Contact Requests
- (NSArray<NSDictionary<NSString*,NSString*>*>*)trustRequestsWithAccountId:(NSString*)accountId;
- (BOOL)acceptTrustRequestFromContact:(NSString*)ringId withAccountId:(NSString*)accountId;
- (BOOL)discardTrustRequestFromContact:(NSString*)ringId withAccountId:(NSString*)accountId;
- (void)sendTrustRequestToContact:(NSString*)ringId payload:(NSData*)payload withAccountId:(NSString*)accountId;

//Contacts
- (void)addContactWithURI:(NSString*)uri accountId:(NSString*)accountId;
- (void)removeContactWithURI:(NSString*)uri accountId:(NSString*)accountId ban:(BOOL)ban;
- (NSDictionary*)contactDetailsWithURI:(NSString*)uri accountId:(NSString*)accountId;
- (NSArray<NSDictionary<NSString*,NSString*>*>*)contactsWithAccountId:(NSString*)accountId;

@end
