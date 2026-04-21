/*
 *  Copyright (C) 2026 - 2026 Savoir-faire Linux Inc.
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

NS_ASSUME_NONNULL_BEGIN

extern NSString* const ContactsFileKeyURI;
extern NSString* const ContactsFileKeyAdded;
extern NSString* const ContactsFileKeyRemoved;
extern NSString* const ContactsFileKeyConfirmed;
extern NSString* const ContactsFileKeyBanned;
extern NSString* const ContactsFileKeyConversationId;

@interface ContactsFileReader : NSObject

+ (NSArray<NSDictionary<NSString*, id>*>*)readForAccount:(NSString*)accountId;

// Reads the contacts file and returns one entry per active contact (banned and
// removed entries are filtered out). Each dictionary has a single key — `"id"`
// — matching `FilterKeys.contactId` consumed by the NSE's `IncomingCallFilter`.
// Briefly retries once if the file is present but empty (race between daemon).
+ (NSArray<NSDictionary<NSString*, NSString*>*>*)activeContactURIsForAccount:(NSString*)accountId;

@end

NS_ASSUME_NONNULL_END
