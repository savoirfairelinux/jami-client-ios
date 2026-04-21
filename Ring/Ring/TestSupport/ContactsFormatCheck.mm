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

#import "ContactsFormatCheck.h"
#import "ContactShallow.h"
#import "Ring-Swift.h"

@implementation ContactsFormatCheck

+ (NSString*)runForAccount:(NSString*)accountId
                     peerA:(NSString*)peerA
                     peerB:(NSString*)peerB {
    NSURL* contactsURL = [[[Constants documentsPath]
                           URLByAppendingPathComponent:accountId]
                          URLByAppendingPathComponent:@"contacts"];
    auto contacts = jami_ios::readContactsMap([contactsURL.path UTF8String]);
    if (contacts.empty()) {
        return @"FAIL: contacts file missing, empty, or failed to decode";
    }

    auto findById = [&](NSString* hexId) -> const jami_ios::ContactShallow* {
        for (const auto& pair : contacts) {
            if ([@(pair.first.toString().c_str()) isEqualToString:hexId]) {
                return &pair.second;
            }
        }
        return nullptr;
    };

    const auto* active = findById(peerA);
    const auto* banned = findById(peerB);

    if (!active) return [NSString stringWithFormat:@"FAIL: active contact %@ not found", peerA];
    if (!banned) return [NSString stringWithFormat:@"FAIL: banned contact %@ not found", peerB];
    if (active->added <= 0) return @"FAIL: active.added should be a positive timestamp";
    if (active->removed != 0) return @"FAIL: active.removed should be 0";
    if (active->banned) return @"FAIL: active.banned should be false";
    if (banned->added <= 0) return @"FAIL: banned.added should be a positive timestamp";
    if (banned->removed <= 0) return @"FAIL: banned.removed should be a positive timestamp after ban";
    if (!banned->banned) return @"FAIL: banned.banned should be true";

    return @"PASS";
}

@end
