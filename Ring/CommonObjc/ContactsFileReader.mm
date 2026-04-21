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

#import "ContactsFileReader.h"
#import "StoredContact.h"

// Compiled into both Ring main and jamiNotificationExtension targets — each
// generates its own *-Swift.h for `Constants`.
#if __has_include("jamiNotificationExtension-Swift.h")
#import "jamiNotificationExtension-Swift.h"
#elif __has_include("Ring-Swift.h")
#import "Ring-Swift.h"
#endif

#import <chrono>
#import <filesystem>
#import <thread>

NSString* const ContactsFileKeyURI            = @"uri";
NSString* const ContactsFileKeyAdded          = @"added";
NSString* const ContactsFileKeyRemoved        = @"removed";
NSString* const ContactsFileKeyConfirmed      = @"confirmed";
NSString* const ContactsFileKeyBanned         = @"banned";
NSString* const ContactsFileKeyConversationId = @"conversationId";

static NSString* contactsFilePath(NSString* accountId) {
    return [[[[Constants documentsPath]
              URLByAppendingPathComponent:accountId]
             URLByAppendingPathComponent:@"contacts"] path];
}

@implementation ContactsFileReader

+ (NSArray<NSDictionary<NSString*, id>*>*)readForAccount:(NSString*)accountId {
    auto contacts = jami_ios::readContactsMap([contactsFilePath(accountId) UTF8String]);
    NSMutableArray<NSDictionary<NSString*, id>*>* result =
        [NSMutableArray arrayWithCapacity:contacts.size()];
    for (const auto& pair : contacts) {
        [result addObject:@{
            ContactsFileKeyURI:            @(pair.first.toString().c_str()),
            ContactsFileKeyAdded:          @(pair.second.added),
            ContactsFileKeyRemoved:        @(pair.second.removed),
            ContactsFileKeyConfirmed:      @(pair.second.confirmed),
            ContactsFileKeyBanned:         @(pair.second.banned),
            ContactsFileKeyConversationId: @(pair.second.conversationId.c_str()),
        }];
    }
    return result;
}

+ (NSArray<NSDictionary<NSString*, NSString*>*>*)activeContactURIsForAccount:(NSString*)accountId {
    const char* path = [contactsFilePath(accountId) UTF8String];
    auto contacts = jami_ios::readContactsMap(path);
    if (contacts.empty()) {
        std::error_code ec;
        auto size = std::filesystem::file_size(path, ec);
        if (!ec && size == 0) {
            std::this_thread::sleep_for(std::chrono::milliseconds(50));
            contacts = jami_ios::readContactsMap(path);
        }
    }
    NSMutableArray<NSDictionary<NSString*, NSString*>*>* result = [NSMutableArray array];
    for (const auto& pair : contacts) {
        if (pair.second.banned) continue;
        if (pair.second.added <= pair.second.removed) continue;
        [result addObject:@{ @"id": @(pair.first.toString().c_str()) }];
    }
    return result;
}

@end
