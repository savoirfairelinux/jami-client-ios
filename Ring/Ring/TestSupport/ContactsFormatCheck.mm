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

static NSString* MsgpackTypeName(msgpack::type::object_type t) {
    switch (t) {
        case msgpack::type::NIL:              return @"NIL";
        case msgpack::type::BOOLEAN:          return @"BOOLEAN";
        case msgpack::type::POSITIVE_INTEGER: return @"POSITIVE_INTEGER";
        case msgpack::type::NEGATIVE_INTEGER: return @"NEGATIVE_INTEGER";
        case msgpack::type::STR:              return @"STR";
        case msgpack::type::BIN:              return @"BIN";
        case msgpack::type::ARRAY:            return @"ARRAY";
        case msgpack::type::MAP:              return @"MAP";
        case msgpack::type::EXT:              return @"EXT";
        default:                              return [NSString stringWithFormat:@"OTHER(%d)", (int)t];
    }
}

@implementation ContactsFormatCheck

#if DEBUG

+ (NSString*)runForAccount:(NSString*)accountId
                     peerA:(NSString*)peerA
                     peerB:(NSString*)peerB {
    NSURL* contactsURL = [[[Constants documentsPath]
                           URLByAppendingPathComponent:accountId]
                          URLByAppendingPathComponent:@"contacts"];

    std::ifstream file([contactsURL.path UTF8String], std::ios_base::in | std::ios_base::binary);
    if (!file.is_open()) return @"FAIL: contacts file missing";
    std::vector<char> buffer((std::istreambuf_iterator<char>(file)),
                             std::istreambuf_iterator<char>());
    file.close();
    if (buffer.empty()) return @"FAIL: contacts file is empty";

    msgpack::object_handle oh;
    try {
        oh = msgpack::unpack(buffer.data(), buffer.size());
    } catch (const std::exception& e) {
        return [NSString stringWithFormat:@"FAIL: msgpack unpack failed: %s", e.what()];
    }
    msgpack::object top = oh.get();
    if (top.type != msgpack::type::MAP || top.via.map.size == 0)
        return @"FAIL: contacts top-level is not a non-empty map";

    // Schema guard: validate each field's NAME and msgpack TYPE on one Contact
    NSDictionary<NSString*, NSNumber*>* expectedTypes = @{
        @"added":          @((int)msgpack::type::POSITIVE_INTEGER),
        @"removed":        @((int)msgpack::type::POSITIVE_INTEGER),
        @"confirmed":      @((int)msgpack::type::BOOLEAN),
        @"banned":         @((int)msgpack::type::BOOLEAN),
        @"conversationId": @((int)msgpack::type::STR),
    };
    msgpack::object entry = top.via.map.ptr[0].val;
    if (entry.type != msgpack::type::MAP)
        return @"FAIL: Contact entry is not a msgpack map";
    NSMutableSet<NSString*>* actualKeys = [NSMutableSet set];
    for (uint32_t i = 0; i < entry.via.map.size; ++i) {
        const msgpack::object& k = entry.via.map.ptr[i].key;
        const msgpack::object& v = entry.via.map.ptr[i].val;
        if (k.type != msgpack::type::STR)
            return @"FAIL: Contact field key is not a string";
        NSString* name = [[NSString alloc] initWithBytes:k.via.str.ptr
                                                  length:k.via.str.size
                                                encoding:NSUTF8StringEncoding];
        [actualKeys addObject:name];
        NSNumber* exp = expectedTypes[name];
        if (exp && (int)v.type != [exp intValue]) {
            return [NSString stringWithFormat:
                @"FAIL: Contact.%@ msgpack type drift. expected=%@ got=%@",
                name,
                MsgpackTypeName((msgpack::type::object_type)[exp intValue]),
                MsgpackTypeName(v.type)];
        }
    }
    NSSet* expectedKeys = [NSSet setWithArray:[expectedTypes allKeys]];
    if (![actualKeys isEqualToSet:expectedKeys]) {
        NSArray* exp = [[expectedKeys allObjects] sortedArrayUsingSelector:@selector(compare:)];
        NSArray* got = [[actualKeys allObjects] sortedArrayUsingSelector:@selector(compare:)];
        return [NSString stringWithFormat:@"FAIL: Contact field set drift. expected=[%@] got=[%@]",
                [exp componentsJoinedByString:@","],
                [got componentsJoinedByString:@","]];
    }

    // Schema matched — typed conversion should succeed. Use it to run value
    // assertions against the daemon's lifecycle semantics.
    std::map<dht::InfoHash, jami_ios::ContactShallow> contacts;
    try {
        oh.get().convert(contacts);
    } catch (const std::exception& e) {
        return [NSString stringWithFormat:@"FAIL: typed decode failed after schema check: %s", e.what()];
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
    if (active->conversationId.empty())
        return @"FAIL: active.conversationId should be non-empty (startConversation on addContact)";
    if (banned->added <= 0) return @"FAIL: banned.added should be a positive timestamp";
    if (banned->removed <= 0) return @"FAIL: banned.removed should be a positive timestamp after ban";
    if (!banned->banned) return @"FAIL: banned.banned should be true";
    if (!banned->conversationId.empty())
        return @"FAIL: banned.conversationId should be cleared after ban";

    return @"PASS";
}

#endif

@end
